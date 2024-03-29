import { ethers } from 'ethers';
import fs from 'fs';
import * as MelodyRNNArtifact from '../artifacts/contracts/MelodyRNN.sol/MelodyRNN.json';
import * as EIP173ProxyWithReceiveArtifact from '../artifacts/contracts/solc_0.8/proxy/EIP173ProxyWithReceive.sol/EIP173ProxyWithReceive.json';
import * as ModelsArtifact from '../artifacts/contracts/Models.sol/Models.json';
import dotenv from 'dotenv';

dotenv.config();

const ContractName = "Models";
const MaxWeightLen = 1000;
const MaxLayerType = 9;
const gasConfig = { gasLimit: 10_000_000_000 };
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

function getLayerType(name: string): number {
    let layerType: number = -1;
    if (name === 'Dense') {
        layerType = 0;
    } else if (name === 'Flatten') {
        layerType = 1;
    } else if (name === 'Rescaling') {
        layerType = 2;
    } else if (name === 'InputLayer') {
        layerType = 3;
    } else if (name === 'MaxPooling2D') {
        layerType = 4;
    } else if (name === 'Conv2D') {
        layerType = 5;
    } else if (name === 'Embedding') {
        layerType = 6;
    } else if (name === 'SimpleRNN') {
        layerType = 7;
    } else if (name === 'LSTM') {
        layerType = 8;
    }
    
    return layerType;
}

function getLayerName(type: number): string {
    let layerName: string = "N/A";
    if (type === 0) {
        layerName = 'Dense';
    } else if (type === 1) {
        layerName = 'Flatten';
    } else if (type === 2) {
        layerName = 'Rescaling';
    } else if (type === 3) {
        layerName = 'InputLayer';
    } else if (type === 4) {
        layerName = 'MaxPooling2D';
    } else if (type === 5) {
        layerName = 'Conv2D';
    } else if (type === 6) {
        layerName = 'Embedding';
    } else if (type === 7) {
        layerName = 'SimpleRNN';
    } else if (type === 8) {
        layerName = 'LSTM';
    }
    return layerName;
}

function getActivationType(name: string): number {
    let activationFn: number = -1;
    if (name === 'leakyrelu') {
        activationFn = 0;
    } else if (name === 'linear' || name === 'softmax') {
        activationFn = 1;
    } else if (name === 'relu') {
        activationFn = 2;
    } else if (name === 'sigmoid') {
        activationFn = 3;
    } else if (name === 'tanh') {
        activationFn = 4;
    }
    return activationFn;
}

function getPaddingType(name: string): number {
    let paddingType: number = -1;
    if (name === "valid") {
        paddingType = 0;
    } else if (name === "same") {
        paddingType = 1;
    }
    return paddingType;
}

function getConvSize(
    dim: number[],
    size: number[],
    stride: number[],
    padding: string,
): { 
    out: number[], 
    pad: number[] 
} {
    const out = [], pad = [];
    for (let i = 0; i < 2; ++i) {
        if (padding == "same") {
            out.push((dim[i] + stride[i] - 1) / stride[i]);
            const total_pad = (dim[i] % stride[i] == 0) ? Math.max(size[i] - stride[i], 0) : Math.max(size[i] - dim[i] % stride[i], 0);
            pad.push(total_pad / 2);
        } else if (padding == "valid") {
            // TODO: What if dim[i] < size[i]
            out.push((dim[i] - size[i]) / stride[i] + 1);
            pad.push(0);
        }
    }
    return { out, pad };
}

async function main() {
    const { PRIVATE_KEY, NODE_ENDPOINT, MODELS_NFT_CONTRACT, MODEL_OWNER, CHUNK_LEN } = process.env;
    const MODEL_JSON = "sample-models/emb_touhou.json"
    if (!PRIVATE_KEY) {
        throw new Error("PRIVATE_KEY is not set");
    }
    if (!NODE_ENDPOINT) {
        throw new Error("NODE_ENDPOINT is not set");
    }
    if (!MODEL_JSON) {
        throw new Error("MODEL_JSON is not set");
    }
    if (!MODELS_NFT_CONTRACT || !ethers.utils.isAddress(MODELS_NFT_CONTRACT)) {
        throw new Error("MODELS_NFT_CONTRACT is not set or invalid");
    }
    if (!MODEL_OWNER || !ethers.utils.isAddress(MODEL_OWNER)) {
        throw new Error("MODEL_OWNER is not set");
    }

    console.log(MODEL_JSON);
    const signer = new ethers.Wallet(PRIVATE_KEY, new ethers.providers.JsonRpcProvider(NODE_ENDPOINT));
    const abic = ethers.utils.defaultAbiCoder;

    // load params from file
    const modelParams = JSON.parse(fs.readFileSync(MODEL_JSON, 'utf-8'));
    const params = Object.assign({}, modelParams);

    let weightsFlat: ethers.BigNumber[] = [];
    if (params.weight_b64) {
        const temp = Buffer.from(params.weight_b64, 'base64');
        const floats = new Float32Array(new Uint8Array(temp).buffer);
        for (let i = 0; i < floats.length; i++) {
            weightsFlat.push(ethers.BigNumber.from(String(Math.trunc(floats[i] * 1e18))));
        }
    }

    let weights: ethers.BigNumber[][][] = [];
    let totSize: number[] = [];
    for (let i = 0; i < MaxLayerType; ++i) {
        weights.push([]);
        totSize.push(0);
    }

    let newLayerConfig = [];
    let input_units: any = 0;
    for (let i = 0; i < params.layers_config.config.layers.length; i++) {
        const layer = params.layers_config.config.layers[i];
        let result: String = "";
            
        let layerType = getLayerType(layer.class_name);

        if (layer.class_name === 'Dense') {
            const output_units = layer.config.units;
    
            let activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * output_units + output_units)
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
            result = abic.encode(["uint8", "uint8", "uint256"], [layerType, activationFn, ethers.BigNumber.from(output_units)]);
            input_units = output_units;
        } else if (layer.class_name === 'Flatten') {
            result = abic.encode(["uint8"], [layerType]);
            input_units = input_units[0] * input_units[1] * input_units[2];
        } else if (layer.class_name === 'Rescaling') {
            const n1 = ethers.BigNumber.from(String(layer.config.scale * 1e18))
            const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("1000000000000000000"));
            result = abic.encode(["uint8", "int256", "int256"], [layerType, n1, n2]);
        } else if (layer.class_name === 'InputLayer') {
            const dim = layer.config.batch_input_shape.slice(1);
            if (dim.length == 1 || dim.length == 2) {
                result = abic.encode(["uint8", "uint8"], [layerType, 0]);
                input_units = 1;
            } else if (dim.length == 3) {
                const h = ethers.BigNumber.from(dim[0]);
                const w = ethers.BigNumber.from(dim[1]);
                const c = ethers.BigNumber.from(dim[2]);
                result = abic.encode(["uint8", "uint8", "uint[3]"], [layerType, 1, [h, w, c]]);
                input_units = w;
            } else {
                input_units = dim[0]
            }
        } else if (layer.class_name === 'MaxPooling2D') {
            const f_w = layer.config.pool_size[0];
            const f_h = layer.config.pool_size[1];
            const s_w = layer.config.strides[0];
            const s_h = layer.config.strides[1];
            const padding = layer.config.padding;
    
            result = abic.encode(["uint8", "uint[2]", "uint[2]", "uint8"], [
                layerType,
                [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                getPaddingType(padding),
            ]);
    
            const { out } = getConvSize([input_units[0], input_units[1]], [f_w, f_h], [s_w, s_h], padding);
            input_units = [out[0], out[1], input_units[2]];
        } else if (layer.class_name === 'Conv2D') {
            const filters = layer.config.filters;
            const f_w = layer.config.kernel_size[0];
            const f_h = layer.config.kernel_size[1];
            const s_w = layer.config.strides[0];
            const s_h = layer.config.strides[1];
            const padding = layer.config.padding;
            const d = input_units[2];
    
            let activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            // Filter: (F_W, F_H, D, K)
            let layerWeights = weightsFlat.splice(0, f_w * f_h * d * filters + filters);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint", "uint[2]", "uint[2]", "uint8"], [
                layerType,
                activationFn,
                ethers.BigNumber.from(filters),
                [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                getPaddingType(padding),
            ]);
    
            const { out } = getConvSize([input_units[0], input_units[1]], [f_w, f_h], [s_w, s_h], padding);
            input_units = [out[0], out[1], filters];
        } else if (layer.class_name === 'Embedding') {
            let inputDim = layer.config.input_dim;
            let outputDim = layer.config.output_dim;
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, inputDim * outputDim);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint256", "uint256"], [layerType, ethers.BigNumber.from(inputDim), ethers.BigNumber.from(outputDim)]);
            input_units = outputDim;
        } else if (layer.class_name === 'SimpleRNN') {
            const units = layer.config.units;
            const activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * units + units * units + units);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint256"], [layerType, activationFn, ethers.BigNumber.from(units)]);
            input_units = units;
        } else if (layer.class_name === 'LSTM') {
            const units = layer.config.units;
            console.log("input units to LSTM: ", input_units);
            const activationFn: number = getActivationType(layer.config.activation);
            const recActivationFn: number = getActivationType(layer.config.recurrent_activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * units * 4 + units * units * 4 + units * 4);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;

            result = abic.encode(["uint8", "uint8", "uint8", "uint256", "uint256"], [layerType, activationFn, recActivationFn, ethers.BigNumber.from(units), ethers.BigNumber.from(input_units)]);
            input_units = units;
        } else {
            continue; // handle dropout etc
        }
            
        if (result.length > 0) {
            newLayerConfig.push(result);
        }
    }
    params.layers_config = newLayerConfig.filter((x: any) => x !== null);

    let nftContractAddress = MODELS_NFT_CONTRACT as string;
    const c = new ethers.Contract(nftContractAddress, ModelsArtifact.abi, signer);
    // deploy a MelodyRNN contract
    const MelodyFac = new ethers.ContractFactory(MelodyRNNArtifact.abi, MelodyRNNArtifact.bytecode, signer);
    const mldyImpl = await MelodyFac.deploy(params.model_name, nftContractAddress);
    // const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
    // const initData = MelodyFac.interface.encodeFunctionData("initialize", [params.model_name, nftContractAddress]);
    // const mldyProxy = await ProxyFac.deploy(mldyImpl.address, signer.address, initData);
    // const mldy = MelodyFac.attach(mldyProxy.address);
    const mldy = MelodyFac.attach(mldyImpl.address);
    console.log("Deployed MelodyRNN contract: ", mldy.address);

    console.log("Setting AI model");
    const setWeightTx = await mldy.setModel(params.layers_config, gasConfig);
    await setWeightTx.wait();
    console.log('tx', setWeightTx.hash);

    if (params.vocabulary) {
        console.log("Setting vocabs");
        const vocabs = params.vocabulary;
        const setVocabTx = await mldy.setVocabs(vocabs, gasConfig);
        await setVocabTx.wait();
        console.log('tx', setVocabTx.hash);
    }
    
    const weightStr = JSON.stringify(weights);
    console.log("Total weights len: ", weightStr.length);

    console.log(`Set weights`);
    const maxlen = CHUNK_LEN ? parseInt(CHUNK_LEN) : MaxWeightLen; // do not chunk the weights
    const truncateWeights = (_w: ethers.BigNumber[], maxlen: number) => {
        return _w.splice(0, maxlen);
    }

    const checkForDeployedModel = (receipt: { events: any[]; }) => {
        const deployedEvent = receipt.events?.find((event: { event: string; }) => event.event === 'Deployed');
        if (deployedEvent != null) {
            const owner = deployedEvent.args?.owner;
            const tokenId = deployedEvent.args?.tokenId;
            console.log(`"Deployed" event emitted: owner=${owner}, tokenId=${tokenId}`);
        }
    }

    for (let i = 0; i < MaxLayerType; ++i) {
        if (totSize[i] === 0) continue;
        console.log(`Weight ${getLayerName(i)} size: `, totSize[i]);

        for (let wi = 0; wi < weights[i].length; ++wi) {
            for (let temp = truncateWeights(weights[i][wi], maxlen); temp.length > 0; temp = truncateWeights(weights[i][wi], maxlen)) {
                    
                const appendWeightTx = await mldy.appendWeights(temp, wi, i, gasConfig);
                const receipt = await appendWeightTx.wait();
                console.log(`append layer ${getLayerName(i)} #${wi} (${temp.length}) - tx ${appendWeightTx.hash}`);
                checkForDeployedModel(receipt);
            }
        }            
    }

    const modelUri = "";
    console.log('before mibnt')
    try {
        const tx = await c.safeMint(MODEL_OWNER || signer.address, modelUri, mldy.address, mintConfig);
        const rc = await tx.wait();
        // listen for Transfer event
        const transferEvent = rc.events?.find((event: { event: string; }) => event.event === 'Transfer');
        if (transferEvent != null) {
            const from = transferEvent.args?.from;
            const to = transferEvent.args?.to;
            const tokenId = transferEvent.args?.tokenId;
            console.log("tx:", tx.hash);
            console.log(`Minted new MelodyRNN model, to=${to}, tokenId=${tokenId}`);
        }
        checkForDeployedModel(rc);
    } catch (e) {
        console.error("Error minting model: ", e);
        throw e;
    }
    console.log('after mibnt')
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
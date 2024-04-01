import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import { BigNumber, ethers } from "ethers";
import * as MelodyRNNArtifact from '../artifacts/contracts/MelodyRNN.sol/MelodyRNN.json';
import * as EIP173ProxyWithReceiveArtifact from '../artifacts/contracts/solc_0.8/proxy/EIP173ProxyWithReceive.sol/EIP173ProxyWithReceive.json';
import * as ModelsArtifact from '../artifacts/contracts/Models.sol/Models.json';

import { execSync } from 'child_process';

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

async function measureTime(f: any): Promise<any> {
    const start = Date.now();
    const ret = await f();
    const end = Date.now();
    console.log(`Execution time: ${(end - start) / 1000.0} s`);
    return ret
}

function pixelsToImage(pixels: ethers.BigNumber[], h: number, w: number, c: number): ethers.BigNumber[][][] {
    let ptr = 0;
    let img: ethers.BigNumber[][][] = [];
    for (let i = 0; i < h; ++i) {
        img.push([]);
        for (let j = 0; j < w; ++j) {
            img[i].push([]);
            for (let k = 0; k < c; ++k) {
                img[i][j].push(pixels[ptr]);
                ++ptr;
            }
        }
    }
    return img;
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

task("mint-melody-model-id", "mint model id (and upload weights)")
    .addOptionalParam("model", "model file name", "", types.string)
    .addOptionalParam("contract", "modelRegistry contract address", "", types.string)
    .addOptionalParam("id", "token id", "0", types.string)
    .addOptionalParam("to", "new model owner address", "", types.string)
    .addOptionalParam("uri", "token URI", "", types.string)
    .addOptionalParam("maxlen", "max length for weights/tx", MaxWeightLen, types.int)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);
        const abic = ethers.utils.defaultAbiCoder;

        // load params from file
        const modelParams = JSON.parse(fs.readFileSync(taskArgs.model, 'utf-8'));
        const params = Object.assign({}, modelParams);

        let weightsFlat: ethers.BigNumber[] = [];
        if (params.weight_b64) {
            const temp = Buffer.from(params.weight_b64, 'base64');
            const floats = new Float32Array(new Uint8Array(temp).buffer);
            for (let i = 0; i < floats.length; i++) {
                weightsFlat.push(ethers.BigNumber.from(String(Math.trunc(floats[i] * Math.pow(2, 64)))));
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
                const n1 = ethers.BigNumber.from(String(layer.config.scale * Math.pow(2, 64)))
                const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("18446744073709551616"));
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
                    input_units = [h.toNumber(), w.toNumber(), c.toNumber()];
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

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }
        const c = new ethers.Contract(contractAddress, ModelsArtifact.abi, signer);
        // deploy a MelodyRNN contract
        const MelodyFac = new ethers.ContractFactory(MelodyRNNArtifact.abi, MelodyRNNArtifact.bytecode, signer);
        const mldyImpl = await MelodyFac.deploy(params.model_name, contractAddress);
        // const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
        // const initData = MelodyFac.interface.encodeFunctionData("initialize", [params.model_name, contractAddress]);
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
            const setVocabTx = await mldy.setVocabs(vocabs);
            await setVocabTx.wait();
            console.log('tx', setVocabTx.hash);
        }

        const weightStr = JSON.stringify(weights);
        console.log("Total weights len: ", weightStr.length);

        console.log(`Set weights`);
        const maxlen = taskArgs.maxlen;
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
                    const receipt = await appendWeightTx.wait(2);
                    console.log(`append layer ${getLayerName(i)} #${wi} (${temp.length}) - tx ${appendWeightTx.hash}`);
                    checkForDeployedModel(receipt);
                }
            }            
        }

        const modelUri = "";
        try {
            const tx = await c.safeMint(taskArgs.to || signer.address, modelUri, mldy.address, mintConfig);
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
    });

task("generate-melody", "evaluate model for each layer")
    .addOptionalParam("contract", "modelRegistry contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("count", "number of step", 1, types.int)
    .addOptionalParam("steplen", "number of notes to generate per step", 1, types.int)
    .addOptionalParam("output", "output file path", "output.mid", types.string)
    // .addOptionalParam("offline", "evaluate without sending a tx", true, types.boolean)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const inputLen = 20;
        const stepLen = taskArgs.steplen;
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }

        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddr(tokenId);
        const mldy = new ethers.Contract(modelAddress, MelodyRNNArtifact.abi, signer);

        let startTime = new Date().getTime();

        // let rands = [];
        // for (let i = 0; i < inputLen; i++) {
        //     rands.push(Math.floor(Math.random() * 130)); // integers ranged [0,129]
        // }

        let vocabs: ethers.BigNumber[] = await mldy.getVocabs();

        // let rands = [68];
        let rands = [68, 129, 30, 31, 32, 35, 129, 37];
        for (let i = rands.length; i < inputLen; i++) {
            const idx = Math.floor(Math.random() * vocabs.length);
            rands.unshift(vocabs[idx].toNumber()); // integers ranged [0,129]
        }

        console.log(rands);

        let x2 = rands.map(n => ethers.BigNumber.from(String(Math.trunc(n * Math.pow(2, 64)))));
        // console.log("x2:", x2);
        
        let melody: any[] = [];
        for (let i = 0; i < taskArgs.count; i++) {
            // let tx = await mldy.generateMelody(tokenId, stepLen, x2, gasConfig);
            // const rc = await tx.wait();
            // console.log("result:", rc);
            const [res, states] = await mldy.generateMelodyTest(tokenId, stepLen, x2);

            // get event NewMelody
            // const newMelody = rc.events?.find(event => event.event === 'NewMelody');
            // if (newMelody != null) {
                // const res = newMelody.args?.melody;
                const notes = res.map((num: ethers.BigNumber) => Number(num.div(BigNumber.from("18446744073709551616"))))
                // // prevent repetition at the end
                // const last = x2.slice(melody.length-stepLen);
                // let repeated = false;
                // for (let i = 0; i < last.length; i++) {
                //     if (last[i].eq(res[i])) {
                //         repeated = true;
                //         break;
                //     }
                // }
                // if (repeated) { 
                //     res[res.length - 1] = ethers.BigNumber.from(String(Math.trunc(Math.floor(Math.random() * 128) * Math.pow(2, 64))));
                // }
                x2 = x2.concat(res).slice(stepLen);
                melody = melody.concat(notes);
                // sleep for 1s
                await new Promise(r => setTimeout(r, 1000));
            // }
        }
        console.log("generated melody:", melody);

        const cmd = `python scripts/gen_midi.py --data "${JSON.stringify(melody)}" --output-path "${taskArgs.output}"`;
        execSync(cmd);

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / 1000);
    });


task("get-melody-model", "get eternal AI model")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id", "0", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments } = hre;
        const [signer] = await ethers.getSigners();
        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }
        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddr(tokenId);
        console.log("Reading MelodyRNN model at address", modelAddress);
        const mldy = new ethers.Contract(modelAddress, MelodyRNNArtifact.abi, signer);
        // const model = await mldy.getInfo(tokenId);

        // fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));

        // const lstmInfo = await mldy.getLSTMLayer(ethers.BigNumber.from(2));
        // const lstmInfoDec = [
        //     lstmInfo[0].toString(),
        //     lstmInfo[1].toString(),
        //     lstmInfo[2].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[3].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[4].map(num => num.toString()),
        // ]
        // fs.writeFileSync("lstmInfo.json", JSON.stringify(lstmInfoDec));
    });

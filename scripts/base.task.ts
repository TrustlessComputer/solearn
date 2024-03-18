import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers, utils } from "ethers";
import path from 'path';
import * as EternalAIArtifact from '../artifacts/contracts/EternalAI.sol/EternalAI.json';
import * as EIP173ProxyWithReceiveArtifact from '../artifacts/contracts/solc_0.8/proxy/EIP173ProxyWithReceive.sol/EIP173ProxyWithReceive.json';
import * as ModelsArtifact from '../artifacts/contracts/Models.sol/Models.json';

const ContractName = "Models";
const MaxWeightLen = 1000;
const MaxLayerType = 9;
const GasLimit = "90000000000"; // 100 B
const MaxFeePerGas = "1001000000";  // 1e-5 gwei
const MaxPriorityFeePerGas = "1000000000";
// const GasLimit = "290000000"; // 100 M
// const MaxFeePerGas = "10010";  // 1e-5 gwei
// const MaxPriorityFeePerGas = "10000";

const gasConfig = {
  gasLimit: GasLimit,
  maxPriorityFeePerGas: MaxPriorityFeePerGas,
  maxFeePerGas: MaxFeePerGas,
};

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

function recursiveToString(arr: any): any {
    return arr.map((val: any) => Array.isArray(val) ? recursiveToString(val) : val.toString());
}

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
    } else if (name === 'linear') {
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
    for(let i = 0; i < h; ++i) {
        img.push([]);
        for(let j = 0; j < w; ++j) {
            img[i].push([]);
            for(let k = 0; k < c; ++k) {
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
    for(let i = 0; i < 2; ++i) {
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

async function getModelDirents(folder: string): Promise<fs.Dirent[]> {
    const dirs = await fs.promises.readdir(folder, { withFileTypes: true });
    return dirs.filter(dirent => dirent.isFile() && path.extname(dirent.name) == ".json");
}

task("mint-model-id", "mint model id (and upload weights)")
    .addOptionalParam("model", "model file name", "", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
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
                weightsFlat.push(ethers.BigNumber.from(String(Math.trunc(floats[i] * 1e18))));
            }
        }

        let weights: ethers.BigNumber[][][] = [];
        let totSize: number[] = [];
        for(let i = 0; i < MaxLayerType; ++i) {
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
                if (dim.length == 1 && dim[0] == null) {
                    result = abic.encode(["uint8", "uint8"], [layerType, 0]);
                    input_units = 1;
                } else if (dim.length == 3) {
                    const h = ethers.BigNumber.from(dim[0]);
                    const w = ethers.BigNumber.from(dim[1]);
                    const c = ethers.BigNumber.from(dim[2]);
                    result = abic.encode(["uint8", "uint8", "uint[3]"], [layerType, 1, [h, w, c]]);
                    input_units = [h.toNumber(), w.toNumber(), c.toNumber()];
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
                input_units = [ out[0], out[1], filters];
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
                console.log("LSTM units:", units);
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
        params.classes_name =  params.classes_name || [];

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const c = new ethers.Contract(contractAddress, ModelsArtifact.abi, signer);
        // deploy a EternalAI contract
        console.log("Deploying EAI Implement contract");
        const EaiFac = new ethers.ContractFactory(EternalAIArtifact.abi, EternalAIArtifact.bytecode, signer);
        const eaiImpl = await EaiFac.deploy();
        await eaiImpl.deployTransaction.wait();
        const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
        console.log("Deploying EAI Proxy contract");
        const initData = EaiFac.interface.encodeFunctionData("initialize", [params.model_name, params.classes_name, contractAddress]);
        const eaiProxy = await ProxyFac.deploy(eaiImpl.address, signer.address, initData);
        await eaiProxy.deployTransaction.wait();
        const eai = EaiFac.attach(eaiProxy.address);

        console.log("Deployed EternalAI contract: ", eai.address);

        try {
            const tx = await c.safeMint(taskArgs.to || signer.address, tokenId, taskArgs.uri, eai.address, gasConfig);
            await tx.wait();
            console.log("Minted new EternalAI model, tx:", tx.hash);
        } catch (e) {
            const ownerAddress = await c.ownerOf(tokenId).catch(_ => {
                throw e;
            });

            console.log("Model #" + tokenId.toString(), "already exists and belongs to", ownerAddress);
            return;
        }

        console.log("Setting AI model");
        const setWeightTx = await eai.setEternalAI(tokenId, params.layers_config, gasConfig);
        await setWeightTx.wait();
        console.log('tx', setWeightTx.hash);

        if (params.vocabulary) {
            console.log("Setting vocabs");
            const vocabs = params.vocabulary;
            const setVocabTx = await eai.setVocabs(tokenId, vocabs, "[UNK]");
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

        for (let i = 0; i < MaxLayerType; ++i) {
            if (totSize[i] === 0) continue;
            console.log(`Weight ${getLayerName(i)} size: `, totSize[i]);

            for (let wi = 0; wi < weights[i].length; ++wi) {
                for (let temp = truncateWeights(weights[i][wi], maxlen); temp.length > 0; temp = truncateWeights(weights[i][wi], maxlen)) {
                    
                    const appendWeightTx = await eai.appendWeights(tokenId, temp, wi, i, gasConfig);
                    const receipt = await appendWeightTx.wait(2);
                    console.log(`append layer ${getLayerName(i)} #${wi} (${temp.length}) - tx ${appendWeightTx.hash}`);
                    const deployedEvent = receipt.events?.find(event => event.event === 'Deployed');
                    if (deployedEvent != null) {
                        const owner = deployedEvent.args?.owner;
                        const tokenId = deployedEvent.args?.tokenId;
                        console.log(`"Deployed" event emitted: owner=${owner}, tokenId=${tokenId}`);
                    }
                }
            }
        }
    });

task("mint-models", "mint multiple model in a folder (with their weights)")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("folder", "folder path", "", types.string)
    .addOptionalParam("maxlen", "max length for weights/tx", MaxWeightLen, types.int)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        const folder = taskArgs.folder;
        const modelDirents = await getModelDirents(folder);
        
        const models = modelDirents.map((dirent, index) => ({
            name: path.basename(dirent.name, '.json'),
            path: path.join(folder, dirent.name),
            id: utils.keccak256(utils.toUtf8Bytes(dirent.name + "v1.0")),
        }));

        const modelInfos = [{"name":"Alien","id":"0x2971776e597fcdf04b51943c02500a5f2c37d70474ce531f8106729ae1497509"},{"name":"Ape","id":"0x6b4d0f0900b58882d95a1a4bc916b532afafa19945ae76a61bc3b1256d600c31"},{"name":"Female","id":"0x451dcda49d1704e9d98da55a3f03ea76713231a47464e4a1545877246ab163ce"},{"name":"Male","id":"0xa965627403bfb51ef963344b4534986cd2731859dee5c9b7448dfea830db71fc"},{"name":"Zombie","id":"0xd7872a355fdd068abaed442af0ade744992f2eb128b9326bca012bdcd7018745"}];
        for(const model of models) {
            console.log("Minting model:", model.name);
            await hre.run("mint-model-id", {
                model: model.path, 
                contract: taskArgs.contract,
                id: model.id,
                maxlen: taskArgs.maxlen,
            });
            modelInfos.push({
                name: model.name,
                id: model.id,
            })
        }

        fs.writeFileSync("model_list.json", JSON.stringify(modelInfos));
    });

task("eval-img", "evaluate model for each layer")
    .addOptionalParam("img", "image file name", "image.png", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
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
        const modelContract = new ethers.Contract(modelAddress, EternalAIArtifact.abi, signer);

        const imgRaw = fs.readFileSync(taskArgs.img);
        console.log("imgRaw: ", imgRaw);
        // TODO: Get inputDim from EternalAI and use the width and height from inputDim instead
        // How to get input image size?

        const model = await modelContract.getInfo();
        const inputDim = model[0];
        if (inputDim.length < 2) {
            throw new Error("Invalid model input dim");
        }
        const w = inputDim[0].toNumber();
        const h = inputDim[1].toNumber();

        const img = sharp(imgRaw);
        // const metadata = await img.metadata(); 
        // const w = metadata.width;
        // const h = metadata.height;
        // if (!w || !h) {
        //     console.log('width and height metadata not found');
        //     return;
        // }

        const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
        const imgArray = [...imgBuffer];
        const pixels = imgArray.map((b: any) =>
            ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

        let numLayers = model[3].length;
        let batchLayerNum = 1;
        let inputs = pixels;
        let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(h), ethers.BigNumber.from(w), ethers.BigNumber.from(3)];
        let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, h, w, 3);
        let x2: ethers.BigNumber[] = [];
        let classsNameRes = "";

        let startTime = new Date().getTime();

        for (let i = 0; ; i = i + batchLayerNum) {
            const fromLayerIndex = i;
            const toLayerIndex = i + batchLayerNum - 1;

            console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
            if (x1.length > 0) {
                console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
            }
            if (x2.length > 0) {
                console.log(`x2: (${x2.length})`);
            }

            const tx: ethers.ContractTransaction = await measureTime(async () => {
                return await modelContract.classify(tokenId, fromLayerIndex, toLayerIndex, x1, x2, gasConfig);
            });

            console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
            const receipt = await tx.wait(1);

            console.log(`Used gas: `, receipt.gasUsed);

            const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
            const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
            if (forwardedEvent) {
                const tokenId = forwardedEvent.args?.tokenId;
                const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
                const toLayerIndex = forwardedEvent.args?.toLayerIndex;
                const outputs1 = forwardedEvent.args?.outputs1;
                const outputs2 = forwardedEvent.args?.outputs2;
                console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex });
                x1 = outputs1;
                x2 = outputs2;
            } else if (classifiedEvent) {
                const tokenId = classifiedEvent.args?.tokenId;
                const classIndex = classifiedEvent.args?.classIndex;
                const className = classifiedEvent.args?.className;
                const outputs = classifiedEvent.args?.outputs;
                console.log('"Classified" event emitted', { tokenId, classIndex, className });
                classsNameRes = className;
            }

            if (toLayerIndex >= numLayers - 1) {
                break;
            }
        }

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / (60 * 1000));
    });

task("gas-generate-text", "estimate gas of generate-text")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }

        const prompt = "Q";
        const seed = ethers.BigNumber.from(123);

        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const modelAddress = await c.modelAddr(ethers.BigNumber.from(taskArgs.id));
        const modelContract = new ethers.Contract(modelAddress, EternalAIArtifact.abi, signer);

        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const temperature = ethers.BigNumber.from(1.0).mul(ethers.constants.WeiPerEther);

        let startTime = new Date().getTime();

        for(let i = 1; i <= 100; ++i) {
            const toGenerate = ethers.BigNumber.from(i);
            const gas = await modelContract.estimateGas.generateText(tokenId, prompt, toGenerate, seed, temperature, gasConfig);
            console.log(i, gas);
        }

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / (1000));
    });

task("generate-text", "generate text from RNN model")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("prompt", "input prompt", "", types.string)
    .addOptionalParam("togenerate", "number of characters to be generated", 100, types.int)
    .addOptionalParam("seed", "random seed", 123, types.int)
    .addOptionalParam("temperature", "randomness of the generation", 1.0, types.float)
    .addOptionalParam("cuda", "1 if the model use cuda, 0 otherwise", 1, types.int)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }

        const prompt = taskArgs.prompt;
        const seed = taskArgs.seed;
        const toGenerate = taskArgs.togenerate;

        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddr(tokenId);
        const modelContract = new ethers.Contract(modelAddress, EternalAIArtifact.abi, signer);
        const temperature = ethers.BigNumber.from(taskArgs.temperature * 1000).mul(ethers.constants.WeiPerEther).div(1000);

        let startTime = new Date().getTime();

        const tx = await modelContract.generateText(tokenId, prompt, toGenerate, seed, temperature, gasConfig);
        const rc = await tx.wait();

        const textGeneratedEvent = rc.events?.find(event => event.event === 'TextGenerated');
        if (textGeneratedEvent) {
            const text = textGeneratedEvent.args?.result;
            console.log("-------------- Prompt + Generated text --------------");
            console.log(prompt + text);
            console.log("-----------------------------------------------------");
        }
        console.log(`Used gas: `, rc.gasUsed);

        const testRNNOutputEvents = rc.events?.filter(event => event.event === 'TestRNNOutput').map(event => event.args.data).map(arr => recursiveToString(arr));
        const testEntropyEvents = rc.events?.filter(event => event.event === 'TestEntropy').map(event => event.args.data).map(arr => recursiveToString(arr));
        const testProbsEvents = rc.events?.filter(event => event.event === 'TestProbs').map(event => event.args.data).map(arr => recursiveToString(arr));
        const testDenseEvents = rc.events?.filter(event => event.event === 'TestDense').map(event => [event.args.x, event.args.w, event.args.tmp, event.args.b, event.args.y, event.args.res]).map(arr => recursiveToString(arr));

        const testMatmulEvents = rc.events?.filter(event => event.event === 'TestMatMul');
        const testMatmulData = testMatmulEvents.map(event => event.args.data);
        const testMatmulDec = testMatmulData.map(mat => mat.map(arr => recursiveToString(arr)));

        if (taskArgs.cuda === 1) {
            fs.writeFileSync("cuda_RNNOutput.json", JSON.stringify(testRNNOutputEvents));
            fs.writeFileSync("cuda_Entropy.json", JSON.stringify(testEntropyEvents));
            fs.writeFileSync("cuda_Probs.json", JSON.stringify(testProbsEvents));
            fs.writeFileSync("cuda_Dense.json", JSON.stringify(testDenseEvents));
            fs.writeFileSync("cuda_events.json", JSON.stringify(testMatmulDec));    
        } else {
            fs.writeFileSync("no_cuda_RNNOutput.json", JSON.stringify(testRNNOutputEvents));
            fs.writeFileSync("no_cuda_Entropy.json", JSON.stringify(testEntropyEvents));
            fs.writeFileSync("no_cuda_Probs.json", JSON.stringify(testProbsEvents));
            fs.writeFileSync("no_cuda_Dense.json", JSON.stringify(testDenseEvents));
            fs.writeFileSync("no_cuda_events.json", JSON.stringify(testMatmulDec));    
        }

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / (1000));
    });

task("get-model", "get eternal AI model")
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
        const modelContract = new ethers.Contract(modelAddress, EternalAIArtifact.abi, signer);
        const model = await modelContract.getInfo();

        fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));

        // const lstmInfo = await c.getLSTMLayer(tokenId, ethers.BigNumber.from(0));
        // const lstmInfoDec = [
        //     lstmInfo[0].toString(),
        //     lstmInfo[1].toString(),
        //     lstmInfo[2].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[3].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[4].map(num => num.toString()),
        // ]
        // fs.writeFileSync("lstmInfo.json", JSON.stringify(lstmInfoDec));
    });

task("get-model-ids")
    .addOptionalParam("folder", "folder path", "", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        const folder = taskArgs.folder;
        const modelDirents = await getModelDirents(folder);
        
        const models = modelDirents.map((dirent, index) => ({
            name: path.basename(dirent.name, '.json'),
            id: ethers.BigNumber.from(utils.keccak256(utils.toUtf8Bytes(dirent.name + "v1.0"))).toString(),
        }));

        fs.writeFileSync("model_list_2.json", JSON.stringify(models));
    })

task("check-models")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("folder", "folder path", "", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);
        
        const c = await ethers.getContractAt(ContractName, taskArgs.contract, signer);
        const modelAddress = await c.modelAddr(ethers.BigNumber.from(1));
        const modelContract = new ethers.Contract(modelAddress, EternalAIArtifact.abi, signer);
        const folder = taskArgs.folder;
        const modelDirents = await getModelDirents(folder);
        
        const models = modelDirents.map(dirent => ({
            name: path.basename(dirent.name, '.json'),
            id: utils.keccak256(utils.toUtf8Bytes(dirent.name + "v1.0")),
        }));

        for(const model of models) {
            const data = await modelContract.getInfo();
            if (!data[0][0].eq(ethers.BigNumber.from(24))) {
                console.log(`Model ${model.name} at id ${model.id} not found`);
            }
        }

        fs.writeFileSync("model_list_2.json", JSON.stringify(models));
    })

// task("check-matmul")
//     .addOptionalParam("")
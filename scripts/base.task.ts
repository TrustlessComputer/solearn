import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers } from "ethers";


const ContractName = "EternalAI";
const MaxWeightLen = 1000;
const MaxLayerType = 8;

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

function pixelsToImage(pixels: ethers.BigNumber[], w: number, h: number, c: number): ethers.BigNumber[][][] {
    let ptr = 0;
    let img: ethers.BigNumber[][][] = [];
    for(let i = 0; i < w; ++i) {
        img.push([]);
        for(let j = 0; j < h; ++j) {
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

task("mint-model-id", "mint model id (and upload weights)")
    .addOptionalParam("model", "model file name", "", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id", "0", types.string)
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
                    const w = ethers.BigNumber.from(dim[0]);
                    const h = ethers.BigNumber.from(dim[1]);
                    const c = ethers.BigNumber.from(dim[2]);
                    result = abic.encode(["uint8", "uint8", "uint[3]"], [layerType, 1, [w, h, c]]);
                    input_units = [w.toNumber(), h.toNumber(), c.toNumber()];
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
            } 
            newLayerConfig.push(result);
        }
        params.layers_config = newLayerConfig.filter((x: any) => x !== null);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ContractName);
            contractAddress = baseContract.address;
        }
        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        try {
            const tx = await c.safeMint(signer.address, tokenId, taskArgs.uri, params.model_name, params.classes_name, { value: ethers.utils.parseEther("0.01") });
            await tx.wait();
            console.log("Minted new EternalAI model, tx:", tx.hash);
        } catch (e) {
            const ownerAddress = await c.ownerOf(tokenId).catch(_ => {
                throw e;
            });
            if (ethers.utils.getAddress(ownerAddress) === ethers.utils.getAddress(signer.address)) {
                console.log("Using existing EternalAI model #" + tokenId.toString());
            } else {
                console.log("EternalAI #" + tokenId.toString(), "already exists and belongs to", ownerAddress);
                return;
            }
        }

        console.log("Setting AI model");

        const setWeightTx = await c.setEternalAI(tokenId, params.layers_config);
        await setWeightTx.wait();
        console.log('tx', setWeightTx.hash);

        const weightStr = JSON.stringify(weights);
        console.log("Total weights len: ", weightStr.length);

        console.log(`Set weights`);
        const maxlen = taskArgs.maxlen;
        const truncateWeights = (_w: ethers.BigNumber[], maxlen: number) => {
            return _w.splice(0, maxlen);
        }

        for(let i = 0; i < MaxLayerType; ++i) {
            if (totSize[i] === 0) continue;
            console.log(`Weight ${getLayerName(i)} size: `, totSize[i]);
            for(let wi = 0; wi < weights[i].length; ++wi) {
                for (let temp = truncateWeights(weights[i][wi], maxlen); temp.length > 0; temp = truncateWeights(weights[i][wi], maxlen)) {
                    const setWeightTx = await c.appendWeights(tokenId, temp, wi, i);
                    const receipt = await setWeightTx.wait(2);
                    console.log(`append layer ${getLayerName(i)} #${wi} (${temp.length}) - tx ${setWeightTx.hash}`);
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

task("eval-img", "evaluate model for each layer")
    .addOptionalParam("img", "image file name", "image.png", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("offline", "evaluate without sending a tx", true, types.boolean)
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

        const imgRaw = fs.readFileSync(taskArgs.img);
        console.log("imgRaw: ", imgRaw);
        // TODO: Get inputDim from EternalAI and use the width and height from inputDim instead
        // How to get input image size?

        const img = sharp(imgRaw);
        const metadata = await img.metadata(); 
        const w = metadata.width;
        const h = metadata.height;
        const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
        const imgArray = [...imgBuffer];
        const pixels = imgArray.map((b: any) =>
            ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

        const model = await c.getInfo(tokenId);
        let numLayers = model[3].length;
        let batchLayerNum = 1;
        let inputs = pixels;
        let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(w), ethers.BigNumber.from(h), ethers.BigNumber.from(3)];
        let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, w, h, 3);
        let x2: ethers.BigNumber[] = [];
        let classsNameRes = "";

        let startTime = new Date().getTime();

        if (taskArgs.offline) {
            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;

                console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
                if (x1.length > 0) {
                    console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
                    // fs.writeFileSync(`x1_${i}.json`, JSON.stringify(x1));
                }
                if (x2.length > 0) {
                    console.log(`x2: (${x2.length})`);
                    // fs.writeFileSync(`x2_${i}.json`, JSON.stringify(x2));
                }
                const [className, r1, r2] = await c.evaluate(tokenId, fromLayerIndex, toLayerIndex, x1, x2, { gasLimit: 1e9 });

                // const [className, r1, r2] = await measureTime(async () => {
                //     return await c.evaluate(tokenId, fromLayerIndex, toLayerIndex, x1, x2);
                // });
                x1 = r1;
                x2 = r2;
                classsNameRes = className;

                if (className != "") {
                    console.log("result: ", className);
                }

                // console.log("result:", output, className);

                if (toLayerIndex >= numLayers - 1) {
                    break;
                }
            }    
        } else {
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
                    return await c.classify(tokenId, fromLayerIndex, toLayerIndex, x1, x2, { value: ethers.utils.parseEther("0.0001") });
                });

                console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
                const receipt = await tx.wait(1);

                const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
                const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
                if (forwardedEvent) {
                    const tokenId = forwardedEvent.args?.tokenId;
                    const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
                    const toLayerIndex = forwardedEvent.args?.toLayerIndex;
                    const outputs1 = forwardedEvent.args?.outputs1;
                    const outputs2 = forwardedEvent.args?.outputs2;
                    console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2 });
                    x1 = outputs1;
                    x2 = outputs2;
                } else if (classifiedEvent) {
                    const tokenId = classifiedEvent.args?.tokenId;
                    const classIndex = classifiedEvent.args?.classIndex;
                    const className = classifiedEvent.args?.className;
                    const outputs = classifiedEvent.args?.outputs;
                    console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs });
                    classsNameRes = className;
                }

                if (toLayerIndex >= numLayers - 1) {
                    break;
                }
            }
        }

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / (60 * 1000));
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
        const model = await c.getInfo(tokenId);

        fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));
    });

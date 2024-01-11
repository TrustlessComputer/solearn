import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers } from "ethers";


const ContractName = "UnstoppableAI";
const MaxWeightLen = 40;

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

function getLayerType(name: string): number {
    // 0 - Dense
    // 1 - Flatten
    // 2 - Rescaling
    // 3 - InputLayer
    // 4 - MaxPooling2D
    // 5 - Conv2D
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
    }
    return layerType;
}

function getLayerName(type: number): string {
    // 0 - Dense
    // 1 - Flatten
    // 2 - Rescaling
    // 3 - InputLayer
    // 4 - MaxPooling2D
    // 5 - Conv2D
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
    }
    return layerName;
}

function getActivationType(name: string): number {
    // activation field to second byte:
    // 0 - LeakyReLU,
    // 1 - Linear,
    // 2 - ReLU,
    // 3 - Sigmoid,
    // 4 - Tanh
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

function getConvSize(
    w: number,
    h: number,
    f_w: number,
    f_h: number,
    s_w: number,
    s_h: number,
    padding: string,
) {
    let W = 0, H = 0, L = 0, R = 0, T = 0, B = 0;

    if (padding == "same") {
        W = (w + s_w - 1) / s_w;
        H = (h + s_h - 1) / s_h;
        const pad_w = (w % s_w == 0) ? Math.max(f_w - s_w, 0) : Math.max(f_w - w % s_w, 0);
        const pad_h = (h % s_h == 0) ? Math.max(f_h - s_h, 0) : Math.max(f_h - h % s_h, 0);
        L = pad_w / 2; R = pad_w - L;
        T = pad_h / 2; B = pad_h - T;
    } else if (padding = "valid") {
        W = (w - f_w) / s_w + 1;
        H = (h - f_h) / s_h + 1;
    }

    return { W, H, L, R, T, B };
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

        let weightDenseMats = [];
        let biasesDense = [];
        let weightConv2DMats = [];
        let biasesConv2D = [];

        let weightDenseMatsSize = 0;
        let weightConv2DMatsSize = 0;

        let newLayerConfig = [];
        let input_units: any = 0;
        for (let i = 0; i < params.layers_config.config.layers.length; i++) {
            const layer = params.layers_config.config.layers[i];
            let result: String = "";
            // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
            if (layer.class_name === 'Dense') {
                let temp = ethers.BigNumber.from(layer.config.units).toHexString();
                const output_units = layer.config.units;

                let activationFn: number = getActivationType(layer.config.activation);

                // reconstruct weights
                let w = [];
                let wsize = 0;
                for (let i = 0; i < input_units; i++) {
                    let tmp = weightsFlat.splice(0, output_units)
                    w.push(tmp);
                    wsize += tmp.length;
                }

                weightDenseMatsSize += wsize;
                weightDenseMats.push(w);
                biasesDense.push(weightsFlat.splice(0, output_units));

                result = abic.encode(["uint8", "uint8", "uint256"], [0, activationFn, temp]);
                input_units = output_units;
            } else if (layer.class_name === 'Flatten') {
                result = abic.encode(["uint8"], [1]);
                input_units = input_units[0] * input_units[1] * input_units[2];
            } else if (layer.class_name === 'Rescaling') {
                const n1 = ethers.BigNumber.from(String(layer.config.scale * 1e18))
                const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("1000000000000000000"));
                result = abic.encode(["uint8", "int256", "int256"], [2, n1, n2]);
            } else if (layer.class_name === 'InputLayer') {
                const w = ethers.BigNumber.from(layer.config.batch_input_shape[1])
                const h = ethers.BigNumber.from(layer.config.batch_input_shape[2])
                const c = ethers.BigNumber.from(layer.config.batch_input_shape[3])
                result = abic.encode(["uint8", "uint[3]"], [3, [w, h, c]]);
                input_units = [w.toNumber(), h.toNumber(), c.toNumber()];
            } else if (layer.class_name === 'MaxPooling2D') {
                const f_w = layer.config.pool_size[0];
                const f_h = layer.config.pool_size[1];
                const s_w = layer.config.strides[0];
                const s_h = layer.config.strides[1];
                const padding = layer.config.padding;

                result = abic.encode(["uint8", "uint[2]", "uint[2]", "uint8"], [
                    4,
                    [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                    [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                    getPaddingType(padding),
                ]);

                const { W, H } = getConvSize(input_units[0], input_units[1], f_w, f_h, s_w, s_h, padding);
                input_units = [W, H, input_units[2]];
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
                let w: ethers.BigNumber[][][][] = [];
                let wsize = 0;
                for (let i = 0; i < f_w; i++) {
                    w.push([]);
                    for (let j = 0; j < f_h; j++) {
                        w[i].push([]);
                        for (let k = 0; k < d; k++) {
                            let tmp = weightsFlat.splice(0, filters)
                            w[i][j].push(tmp);
                            wsize += tmp.length;
                        }
                    }
                }

                weightConv2DMatsSize += wsize;
                weightConv2DMats.push(w);
                biasesConv2D.push(weightsFlat.splice(0, filters));

                result = abic.encode(["uint8", "uint8", "uint", "uint[2]", "uint[2]", "uint8"], [
                    5,
                    activationFn,
                    ethers.BigNumber.from(filters),
                    [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                    [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                    getPaddingType(padding),
                ]);

                const { W, H } = getConvSize(input_units[0], input_units[1], f_w, f_h, s_w, s_h, padding);
                input_units = [W, H, filters];
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
            console.log("Minted new perceptron");
        } catch (e) {
            const ownerAddress = await c.ownerOf(tokenId).catch(_ => {
                throw e;
            });
            if (ethers.utils.getAddress(ownerAddress) === ethers.utils.getAddress(signer.address)) {
                console.log("Using existing perceptron #" + tokenId.toString());
            } else {
                console.log("Perceptron #" + tokenId.toString(), "already exists and belongs to", ownerAddress);
                return;
            }
        }

        console.log("Weight dense size: ", weightDenseMatsSize);
        console.log("Weight conv2d size: ", weightConv2DMatsSize);

        console.log(`Set weights`);
        const truncateWeights = (_w: any[][], maxlen: number) => {
            let result = [];
            for (let i = 0; i < _w.length; i++) {
                result.push(_w[i].splice(0, maxlen));
            }
            return result;
        }
        const maxlen = taskArgs.maxlen;


        const tmpDense = truncateWeights(weightDenseMats, maxlen);
        const paramsTmp = [
            tokenId, params.layers_config, tmpDense, biasesDense, weightConv2DMats, biasesConv2D, -1
        ];
        const paramStr = JSON.stringify(paramsTmp);
        console.log("paramStr len: ", paramStr.length);

        const setWeightTx = await c.setWeights(tokenId, params.layers_config, tmpDense, biasesDense, weightConv2DMats, biasesConv2D, -1);
        await setWeightTx.wait();
        console.log('tx', setWeightTx.hash);
        for (let wi = 0; wi < weightDenseMats.length; wi++) {
            let currentWeights = [weightDenseMats[wi]];
            for (let temp = truncateWeights(currentWeights, maxlen); temp[0].length > 0; temp = truncateWeights(currentWeights, maxlen)) {
                const setWeightTx = await c.setWeights(tokenId, params.layers_config, temp, [], [], [], wi);
                await setWeightTx.wait(2);
                console.log('append layer dense #', wi, '- tx', setWeightTx.hash);
            }
        }
        console.log("Set weights done");
    });

task("eval-img", "evaluate perceptron for each layer")
    .addOptionalParam("img", "image file name", "image.png", types.string)
    .addOptionalParam("w", "perceptron input image width", 2, types.int)
    .addOptionalParam("h", "perceptron input image height", 2, types.int)
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

        // console.log(contractAddress);

        const c = await ethers.getContractAt(ContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);

        const img = fs.readFileSync(taskArgs.img);
        console.log("img: ", img);
        // TODO: Get inputDim from perceptron and use the width and height from inputDim instead
        let { w, h } = taskArgs;
        // How to get input image size?
        const imgBuffer = await sharp(img).removeAlpha().resize(w, h).raw().toBuffer();
        const imgArray = [...imgBuffer];
        const pixels = imgArray.map((b: any) =>
            ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

        const perceptron = await c.getInfo(tokenId);
        let numLayers = perceptron[5].length;
        let batchLayerNum = 1;
        let inputs = pixels;
        let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(w), ethers.BigNumber.from(h), ethers.BigNumber.from(3)];
        let x1: any[] = [];
        let x2: any[] = [];
        let classsNameRes = "";

        // await measureTime(async () => {
        //     return await c.test(ethers.BigNumber.from(13243), ethers.BigNumber.from(1e6));
        // });

        // console.log("classsNameRes: ", classsNameRes);

        let startTime = new Date().getTime();

        if (taskArgs.offline) {
            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;

                console.log(`Layer ${i}: ${getLayerName(perceptron[5][i][0])}`)
                const [className, r1, r2] = await measureTime(async () => {
                    return await c.evaluate(tokenId, fromLayerIndex, toLayerIndex, inputs, dim, x1, x2);
                });
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
            // const evPromise = c.once('Classified', (tokenId, classIndex, className, outputs) => {
            //     console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs });
            //     classsNameRes = className;
            // });

            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;
                // const evPromise2 = c.once('Forwarded', (tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2) => {
                // console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2 });
                // x1 = outputs1;
                // x2 = outputs2;
                // });

                console.log(`Layer ${i}: ${getLayerName(perceptron[5][i][0])}`)
                if (x1.length > 0) {
                    console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length}, ${x1[0][0][0].length})`);
                }
                if (x2.length > 0) {
                    console.log(`x2: (${x2.length}, ${x2[0].length})`);
                }

                const tx: ethers.ContractTransaction = await measureTime(async () => {
                    return await c.classify(tokenId, fromLayerIndex, toLayerIndex, inputs, dim, x1, x2, { value: ethers.utils.parseEther("0.0001") });
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


task("get-model", "get perceptron")
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
        const perceptron = await c.getInfo(tokenId);

        fs.writeFileSync("baseDesc.json", JSON.stringify(perceptron));
        // console.log(JSON.stringify(perceptron));
    });

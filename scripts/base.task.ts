import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers } from "ethers";


const ContractName = "UnstoppableAI";
const MaxWeightLen = 40;

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

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

        console.log("weightsFlat length: ", weightsFlat.length);

        let weightMats = [];
        let biases = [];

        let weightMatsSize = 0;

        let newLayerConfig = [];
        let input_units = 0;
        for (let i = 0; i < params.layers_config.config.layers.length; i++) {
            const layer = params.layers_config.config.layers[i];
            let result: String = "";
            // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
            if (layer.class_name === 'Dense') {

                let temp = ethers.BigNumber.from(layer.config.units).toHexString();
                const output_units = layer.config.units;

                console.log(`Layer index ${i} - output_units ${output_units} - input_units ${input_units}`);
                // activation field to second byte:
                // 0 - LeakyReLU,
                // 1 - Linear,
                // 2 - ReLU,
                // 3 - Sigmoid,
                // 4 - Tanh
                let activationFn: number = 0;
                if (layer.config.activation === 'LeakyReLU') {
                    activationFn = 0;
                } else if (layer.config.activation === 'Linear') {
                    activationFn = 1;
                } else if (layer.config.activation === 'ReLU') {
                    activationFn = 2;
                } else if (layer.config.activation === 'Sigmoid') {
                    activationFn = 3;
                } else if (layer.config.activation === 'Tanh') {
                    activationFn = 4;
                }

                // reconstruct weights
                let w = [], b = [];
                let wsize = 0;
                for (let i = 0; i < input_units; i++) {
                    let tmp = weightsFlat.splice(0, output_units)
                    w.push(tmp);
                    wsize += tmp.length;
                }

                console.log(`Layer index ${i} - output_units ${output_units} - input_units ${input_units} - w temp length: ${w.length}`);

                weightMatsSize += wsize;
                weightMats.push(w);
                biases.push(weightsFlat.splice(0, output_units));

                result = abic.encode(["uint8", "uint8", "uint256"], [0, activationFn, temp]);
                input_units = output_units;
            } else if (layer.class_name === 'Flatten') {
                result = abic.encode(["uint8"], [1]);
            } else if (layer.class_name === 'Rescaling') {
                const n1 = ethers.BigNumber.from(String(layer.config.scale * 1e18))
                const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("1000000000000000000"));
                result = abic.encode(["uint8", "int256", "int256"], [2, n1, n2]);
            } else if (layer.class_name === 'InputLayer') {
                const w = ethers.BigNumber.from(layer.config.batch_input_shape[1])
                const h = ethers.BigNumber.from(layer.config.batch_input_shape[2])
                const c = ethers.BigNumber.from(layer.config.batch_input_shape[3])
                result = abic.encode(["uint8", "uint[3]"], [3, [w, h, c]]);
                input_units = w.mul(h).mul(c).toNumber();
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

        console.log("weightMats length: ", weightMats.length);

        console.log("Weight size: ", weightMatsSize);

        console.log(`Set weights`);

        const truncateWeights = (_w: any[][], maxlen: number) => {
            let result = [];
            for (let i = 0; i < _w.length; i++) {
                result.push(_w[i].splice(0, maxlen));
            }
            return result;
        }
        const maxlen = taskArgs.maxlen;


        const tmp = truncateWeights(weightMats, maxlen);
        const paramsTmp = [
            tokenId, params.layers_config, tmp, biases, - 1
        ];
        const paramStr = JSON.stringify(paramsTmp);
        console.log("paramStr len: ", paramStr.length);

        const setWeightTx = await c.setWeights(tokenId, params.layers_config, tmp, biases, -1);
        await setWeightTx.wait();
        console.log('tx', setWeightTx.hash);
        for (let wi = 0; wi < weightMats.length; wi++) {
            let currentWeights = [weightMats[wi]];
            for (let temp = truncateWeights(currentWeights, maxlen); temp[0].length > 0; temp = truncateWeights(currentWeights, maxlen)) {
                const setWeightTx = await c.setWeights(tokenId, params.layers_config, temp, [], wi);

                console.log('append layer dense #', wi, '- tx', setWeightTx.hash);
                await setWeightTx.wait(2);

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



        let numLayers = 7;
        let batchLayerNum = 3;
        let inputs = pixels;
        let pixelMat: any[] = [];
        let classsNameRes = "";

        console.log("classsNameRes: ", classsNameRes);

        if (taskArgs.offline) {
            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;

                const [className, output] = await c.evaluate(tokenId, fromLayerIndex, toLayerIndex, inputs, pixelMat);
                pixelMat = output;
                classsNameRes = className;


                console.log("result:", output, className);

                if (toLayerIndex >= numLayers - 1) {
                    break;
                }
            }

        } else {
            const evPromise = c.once('Classified', (tokenId, classIndex, className, outputs) => {
                console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs });
                classsNameRes = className;
            });

            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;
                const evPromise2 = c.once('Forwarded', (tokenId, fromLayerIndex, toLayerIndex, outputs) => {
                    console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs });
                    pixelMat = outputs;
                });

                const tx = await c.classify(tokenId, fromLayerIndex, toLayerIndex, inputs, pixelMat, { value: ethers.utils.parseEther("0.0001") });
                console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
                await tx.wait(5);

                if (toLayerIndex >= numLayers - 1) {
                    break;
                }
            }
        }
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

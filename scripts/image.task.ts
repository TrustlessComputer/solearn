import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers, utils } from "ethers";
import path from 'path';
import { getLayerName } from "./lib/modelLib";
import { getModelDirents, pixelsToImage, measureTime, postprocessText, toInt } from "./lib/utils";
import { runeToText, isRune } from "./rune.task";

const ImageClassifierContractName = "ImageClassifier";
const ModelRegContractName = "ModelReg";
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
    
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

const evalPrice = ethers.utils.parseEther('0.01');
const evalConfig = { value: evalPrice };

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
            const baseContract = await deployments.get(ModelRegContractName);
            contractAddress = baseContract.address;
        }

        const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await modelRegContract.modelAddr(tokenId);
        const modelContract = await ethers.getContractAt(ImageClassifierContractName, modelAddress, signer);

        const imgRaw = fs.readFileSync(taskArgs.img);
        console.log("imgRaw: ", imgRaw);
        // TODO: Get inputDim from TextRNN and use the width and height from inputDim instead
        // How to get input image size?

        const model = await modelContract.getInfo();
        const inputDim = model[0];
        if (inputDim.length < 2) {
            throw new Error("Invalid model input dim");
        }
        const h = inputDim[0].toNumber();
        const w = inputDim[1].toNumber();

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
        const pixels = imgArray.map((b: any) => toInt(b));

        let numLayers = model[3].length;
        let batchLayerNum = 1;
        let inputs = pixels;
        let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(h), ethers.BigNumber.from(w), ethers.BigNumber.from(3)];
        let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, h, w, 3);
        let x2: ethers.BigNumber[] = [];
        let classsNameRes = "";
        let confidence = ethers.BigNumber.from("0");

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

            // const tx: ethers.ContractTransaction = await measureTime(async () => {
            //     return await modelContract.classify(fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig });
            // });
            const tx: ethers.ContractTransaction = await modelContract.classify(fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig });
            const receipt = await tx.wait(1);

            console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
            console.log(`Used gas: `, receipt.gasUsed);

            const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
            const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
            if (forwardedEvent) {
                const tokenId = forwardedEvent.args?.tokenId;
                const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
                const toLayerIndex = forwardedEvent.args?.toLayerIndex;
                const outputs1 = forwardedEvent.args?.outputs1;
                const outputs2 = forwardedEvent.args?.outputs2;
                // console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs2 });
                x1 = outputs1;
                x2 = outputs2;
            } else if (classifiedEvent) {
                const tokenId = classifiedEvent.args?.tokenId;
                const classIndex = classifiedEvent.args?.classIndex;
                const className = classifiedEvent.args?.className;
                const outputs = classifiedEvent.args?.outputs;
                const confidence = classifiedEvent.args?.confidence;
                // console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs, confidence });
                classsNameRes = className;
            }

            if (toLayerIndex >= numLayers - 1) {
                break;
            }
        }                

        let endTime = new Date().getTime();
        console.log("Final prediction:", classsNameRes);
        console.log("Time:", `${(endTime - startTime) / 1000} second`);
    });

task("get-image-model", "get eternal AI model")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id", "0", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments } = hre;
        const [signer] = await ethers.getSigners();
        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ModelRegContractName);
            contractAddress = baseContract.address;
        }
        const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await modelRegContract.modelAddr(tokenId);
        const modelContract = await ethers.getContractAt(ImageClassifierContractName, modelAddress, signer);
        const model = await modelContract.getInfo();

        fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));
    });

import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers, utils } from "ethers";
import path from 'path';
import { pixelsToImage, toInt, toFloat } from "./lib/utils";

const ImageClassifierContractName = "ImageClassifier";
const OnchainModelContractName = "OnchainModel";
const ModelRegContractName = "ModelReg";

task("eval-img", "evaluate model for each layer")
    .addOptionalParam("img", "image file name", "image.png", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);
        const abic = ethers.utils.defaultAbiCoder;

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ModelRegContractName);
            contractAddress = baseContract.address;
        }

        const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const interfaceAddress = await modelRegContract.modelAddr(tokenId);
        const interfaceContract = await ethers.getContractAt(OnchainModelContractName, interfaceAddress, signer);        
        
        const implementAddress = await interfaceContract.implementation();
        const implementContract = await ethers.getContractAt(ImageClassifierContractName, implementAddress, signer);

        const imgRaw = fs.readFileSync(taskArgs.img);
        console.log("imgRaw: ", imgRaw);
        // TODO: Get inputDim from TextRNN and use the width and height from inputDim instead
        // How to get input image size?

        const model = await implementContract.getInfo();
        const inputDim = model[0];
        if (inputDim.length < 2) {
            throw new Error("Invalid model input dim");
        }
        const h = inputDim[0].toNumber();
        const w = inputDim[1].toNumber();

        const img = sharp(imgRaw);
        const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
        const imgArray = [...imgBuffer];
        const pixelsFlat = imgArray.map((b: any) => toInt(b));
        const pixels: ethers.BigNumber[][][] = pixelsToImage(pixelsFlat, h, w, 3);

        console.log("Encoding data");
        const data = abic.encode(["uint64[][][]"], [pixels]);

        let startTime = new Date().getTime();

        console.log("Infering");
        const tx = await interfaceContract.infer(data);
        const rc = await tx.wait();
        const inferResultEvent = rc.events?.find(event => event.event === 'InferResult');
        if (inferResultEvent) {
            const result = inferResultEvent.args?.result;
            const [ className, confidence ] = abic.decode(["string", "uint64"], result);
            console.log(`Predicted class: ${className}, confidence: ${toFloat(confidence) * 100}%`);
        }

        // let numLayers = model[3].length;
        // let batchLayerNum = 1;
        // let inputs = pixels;
        // let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(h), ethers.BigNumber.from(w), ethers.BigNumber.from(3)];
        // let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, h, w, 3);
        // let x2: ethers.BigNumber[] = [];
        // let classsNameRes = "";
        // let confidence = ethers.BigNumber.from("0");

        // let startTime = new Date().getTime();

        // for (let i = 0; ; i = i + batchLayerNum) {
        //     const fromLayerIndex = i;
        //     const toLayerIndex = i + batchLayerNum - 1;

        //     console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
        //     if (x1.length > 0) {
        //         console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
        //     }
        //     if (x2.length > 0) {
        //         console.log(`x2: (${x2.length})`);
        //     }

        //     // const tx: ethers.ContractTransaction = await measureTime(async () => {
        //     //     return await modelContract.classify(fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig });
        //     // });
        //     const tx: ethers.ContractTransaction = await modelContract.classify(fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig });
        //     const receipt = await tx.wait(1);

        //     console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
        //     console.log(`Used gas: `, receipt.gasUsed);

        //     const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
        //     const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
        //     if (forwardedEvent) {
        //         const tokenId = forwardedEvent.args?.tokenId;
        //         const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
        //         const toLayerIndex = forwardedEvent.args?.toLayerIndex;
        //         const outputs1 = forwardedEvent.args?.outputs1;
        //         const outputs2 = forwardedEvent.args?.outputs2;
        //         // console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs2 });
        //         x1 = outputs1;
        //         x2 = outputs2;
        //     } else if (classifiedEvent) {
        //         const tokenId = classifiedEvent.args?.tokenId;
        //         const classIndex = classifiedEvent.args?.classIndex;
        //         const className = classifiedEvent.args?.className;
        //         const outputs = classifiedEvent.args?.outputs;
        //         const confidence = classifiedEvent.args?.confidence;
        //         // console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs, confidence });
        //         classsNameRes = className;
        //     }

        //     if (toLayerIndex >= numLayers - 1) {
        //         break;
        //     }
        // }                

        let endTime = new Date().getTime();
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
        const interfaceAddress = await modelRegContract.modelAddr(tokenId);
        const interfaceContract = await ethers.getContractAt(OnchainModelContractName, interfaceAddress, signer);        
        
        const implementAddress = await interfaceContract.implementation();
        const implementContract = await ethers.getContractAt(ImageClassifierContractName, implementAddress, signer);

        const model = await implementContract.getInfo();

        fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));
    });

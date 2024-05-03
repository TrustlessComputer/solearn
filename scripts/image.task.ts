import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers, utils } from "ethers";
import path from 'path';
import { pixelsToImage, fromInt, toFloat, recursiveToFloat, recursiveToString } from "./lib/utils";

const ImageClassifierContractName = "ImageClassifier";
const OnchainModelContractName = "OnchainModel";
const ModelRegContractName = "ModelReg";

async function inferModel(interfaceContract: ethers.Contract, pixels: ethers.BigNumber[][][]) {
    const abic = ethers.utils.defaultAbiCoder;
    const data = abic.encode(["int64[][][]"], [pixels]);

    const tx = await interfaceContract.infer(data);
    const rc = await tx.wait();
    console.log(`Used gas: `, rc.gasUsed);

    const inferResultEvent = rc.events?.find(event => event.event === 'InferResult');
    if (inferResultEvent) {
        const result = inferResultEvent.args?.result;
        const [ className, confidence ] = abic.decode(["string", "uint64"], result);
        return { className, confidence };
    } else {
        console.log("Infer result event not found");
        return {};
    }
}

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
        const pixelsFlat = imgArray.map((b: any) => fromInt(b));
        const pixels: ethers.BigNumber[][][] = pixelsToImage(pixelsFlat, h, w, 3);

        let startTime = new Date().getTime();

        const { className, confidence } = await inferModel(interfaceContract, pixels);
        console.log(`Predicted class: ${className}, confidence: ${toFloat(confidence) * 100}%`);

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

        // for(let i = 0; i < 3; ++i) {
        //     const { n, m, p, q, w, b} = await implementContract.getConv2DLayer(i);
        //     console.log(n, m, p, q);
        //     const wFloat = recursiveToFloat(w);
        //     const bFloat = recursiveToFloat(b);
        //     fs.writeFileSync(`model_weight_${i*2}.json`, JSON.stringify(wFloat));
        //     fs.writeFileSync(`model_weight_${i*2+1}.json`, JSON.stringify(bFloat));
        // }
        // for(let i = 0; i < 2; ++i) {
        //     const { dim_in, dim_out, w, b } = await implementContract.getDenseLayer(i);
        //     console.log(dim_in, dim_out);
        //     const wFloat = recursiveToFloat(w);
        //     const bFloat = recursiveToFloat(b);
        //     fs.writeFileSync(`model_weight_${6+i*2}.json`, JSON.stringify(wFloat));
        //     fs.writeFileSync(`model_weight_${6+i*2+1}.json`, JSON.stringify(bFloat));
        // }

        fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));
    });

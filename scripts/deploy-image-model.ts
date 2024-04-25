import hre from "hardhat";
import { ethers } from "ethers";
import fs from 'fs';
import * as ImageClassifierArtifact from '../artifacts/contracts/ImageClassifier.sol/ImageClassifier.json';
import dotenv from 'dotenv';
import { fromFloat } from './lib/utils';
import { getModelConfig, uploadModelWeights, mintModel } from './lib/modelLib';
dotenv.config();

const ModelRegContractName = "ModelReg";
const MaxWeightLen = 1000;
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

async function main() {
    const { ethers } = hre;
    const { PRIVATE_KEY, NODE_ENDPOINT, MODEL_JSON, MODELS_NFT_CONTRACT, MODEL_OWNER, CHUNK_LEN } = process.env;
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
    const provider = ethers.getDefaultProvider(NODE_ENDPOINT);
    const signer = new ethers.Wallet(PRIVATE_KEY, provider);

    // load params from file
    const modelParams = JSON.parse(fs.readFileSync(MODEL_JSON, 'utf-8'));
    const params = Object.assign({}, modelParams);

    let weightsFlat: ethers.BigNumber[] = [];
    if (params.weight_b64) {
        const temp = Buffer.from(params.weight_b64, 'base64');
        const floats = new Float32Array(new Uint8Array(temp).buffer);
        for (let i = 0; i < floats.length; i++) {
            weightsFlat.push(fromFloat(floats[i]));
        }
    }

    const { newLayerConfig, weights } = getModelConfig(params, weightsFlat);

    params.layers_config = newLayerConfig.filter((x: any) => x !== null);
    params.classes_name =  params.classes_name || [];

    let nftContractAddress = MODELS_NFT_CONTRACT as string;

    const modelReg = await ethers.getContractAt(ModelRegContractName, nftContractAddress);

    // deploy a ImageClassifier contract
    // ImageClassifier contract is too big (larger than 49152 bytes) to be deployed with ContractFactory
    const ImageFac = new ethers.ContractFactory(ImageClassifierArtifact.abi, ImageClassifierArtifact.bytecode, signer);    
    const imageImpl = await ImageFac.deploy(params.model_name, nftContractAddress);
    // const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
    // const initData = ImageFac.interface.encodeFunctionData("initialize", [params.model_name, params.classes_name, nftContractAddress]);
    // const mldyProxy = await ProxyFac.deploy(mldyImpl.address, signer.address, initData);
    const image = ImageFac.attach(imageImpl.address);
    console.log("Deployed ImageClassifier contract: ", image.address);

    console.log("Setting classes name");    
    const setClassesNameTx = await image.setClassesName(params.classes_name);
    await setClassesNameTx.wait();
    console.log('tx', setClassesNameTx.hash);
        
    console.log("Setting model");
    const setWeightTx = await image.setOnchainModel(params.layers_config);
    await setWeightTx.wait();
    console.log('tx', setWeightTx.hash);

    console.log("Uploading weights");
    const maxlen = CHUNK_LEN ? parseInt(CHUNK_LEN) : MaxWeightLen; // do not chunk the weights
    await uploadModelWeights(image, weights, maxlen);
        
    console.log("Minting new model");
    await mintModel(modelReg, image, MODEL_OWNER || signer.address, mintConfig);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
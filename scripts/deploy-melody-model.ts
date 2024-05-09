import hre from "hardhat";
import { ethers } from 'ethers';
import fs from 'fs';
import * as MelodyRNNArtifact from '../artifacts/contracts/MelodyRNN.sol/MelodyRNN.json';
import dotenv from 'dotenv';
import { fromFloat } from './lib/utils';
import { getModelConfig, uploadModelWeights, mintModel } from './lib/modelLib';

dotenv.config();

const ModelCollectionContractName = "ModelCollection";
const MaxWeightLen = 1000;
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

async function main() {
    const { ethers, upgrades } = hre;
    const { PRIVATE_KEY, NODE_ENDPOINT, MODEL_JSON, MODELS_NFT_CONTRACT, MODEL_OWNER, MODEL_INFERENCE_COST, CHUNK_LEN } = process.env;
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
            weightsFlat.push(fromFloat(floats[i]));
        }
    }

    const { newLayerConfig, weights } = getModelConfig(params, weightsFlat);

    params.layers_config = newLayerConfig.filter((x: any) => x !== null);

    let nftContractAddress = MODELS_NFT_CONTRACT as string;

    const modelCollection = await ethers.getContractAt(ModelCollectionContractName, nftContractAddress);

    // deploy a MelodyRNN contract
    const MelodyFac = new ethers.ContractFactory(MelodyRNNArtifact.abi, MelodyRNNArtifact.bytecode, signer);
    const mldyImpl = await MelodyFac.deploy();
    await mldyImpl.deployed();
    // const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
    // const initData = MelodyFac.interface.encodeFunctionData("initialize", [params.model_name, nftContractAddress]);
    // const mldyProxy = await ProxyFac.deploy(mldyImpl.address, signer.address, initData);
    // const mldy = MelodyFac.attach(mldyProxy.address);
    const mldy = MelodyFac.attach(mldyImpl.address);
    console.log("Deployed MelodyRNN contract: ", mldy.address);

    console.log("Setting vocabs");
    if (!params.vocabulary) {
        console.log("Vocabs must not be empty. Abort deploying model.");
        return;
    }
    const setVocabTx = await mldy.setVocabs(params.vocabulary);
    await setVocabTx.wait();
    console.log('tx', setVocabTx.hash);

    console.log("Setting model");
    const setWeightTx = await mldy.setOnchainModel(params.layers_config);
    await setWeightTx.wait();
    console.log('tx', setWeightTx.hash);

    console.log("Uploading weights");
    const maxlen = CHUNK_LEN ? parseInt(CHUNK_LEN) : MaxWeightLen; // do not chunk the weights
    await uploadModelWeights(mldy, weights, maxlen); 
    console.log("Deploying OnchainModel contract");

    const inferenceCost = ethers.BigNumber.from(MODEL_INFERENCE_COST);
    const OnchainModel = await ethers.getContractFactory('OnchainModel');
    const onchainModel = await upgrades.deployProxy(
        OnchainModel,
        [
            modelCollection.address,
            0,
            params.model_name,
            mldy.address,
            inferenceCost
        ]
    );
    await onchainModel.deployed();
    console.log(`Contract OnchainModel has been deployed to address ${onchainModel.address}`);

    console.log(`Set model inferface`);
    const tx = await mldy.setModelInterface(onchainModel.address);
    await tx.wait();
    console.log("tx:", tx.hash);

    console.log("Minting new model");
    await mintModel(modelCollection, onchainModel, MODEL_OWNER || signer.address, mintConfig);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
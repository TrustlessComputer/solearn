import hre from "hardhat";
import { ethers, utils } from "ethers";
import fs from 'fs';
import * as ImageClassifierArtifact from '../artifacts/contracts/ImageClassifier.sol/ImageClassifier.json';
import dotenv from 'dotenv';
import { fromFloat } from './lib/utils';
import { MaxLayerType, getLayerName, getModelConfig } from './lib/modelLib';
dotenv.config();

const ModelRegContractName = "ModelReg";
const MaxWeightLen = 1000;
const gasConfig = { gasLimit: 10_000_000_000 };
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

    const { newLayerConfig, weights, totSize } = getModelConfig(params, weightsFlat);

    params.layers_config = newLayerConfig.filter((x: any) => x !== null);
    params.classes_name =  params.classes_name || [];

    let tokenId = ethers.BigNumber.from(0); // placeholder
    let nftContractAddress = MODELS_NFT_CONTRACT as string;

    const modelReg = await ethers.getContractAt(ModelRegContractName, nftContractAddress);

    // deploy a ImageClassifier contract
    // ImageClassifier contract is too big (larger than 49152 bytes) to be deployed with ContractFactory
    const EaiFac = new ethers.ContractFactory(ImageClassifierArtifact.abi, ImageClassifierArtifact.bytecode, signer);
    
    const eaiImpl = await EaiFac.deploy(params.model_name, params.classes_name || [], nftContractAddress, gasConfig);
    // const ProxyFac = new ethers.ContractFactory(EIP173ProxyWithReceiveArtifact.abi, EIP173ProxyWithReceiveArtifact.bytecode, signer);
    // const initData = EaiFac.interface.encodeFunctionData("initialize", [params.model_name, params.classes_name, nftContractAddress]);
    // const mldyProxy = await ProxyFac.deploy(mldyImpl.address, signer.address, initData);
    const eai = EaiFac.attach(eaiImpl.address);
    console.log("Deployed ImageClassifier contract: ", eai.address);
        
    const modelUri = ""; // unused
    console.log("Setting AI model");
    const setWeightTx = await eai.setEternalAI(tokenId, params.layers_config, gasConfig);
    await setWeightTx.wait();
    console.log('tx', setWeightTx.hash);

    if (params.vocabulary) {
        console.log("Setting vocabs");
        const vocabs = params.vocabulary;
        const setVocabTx = await eai.setVocabs(tokenId, vocabs, "[UNK]", gasConfig);
        await setVocabTx.wait();
        console.log('tx', setVocabTx.hash);
    }

    const weightStr = JSON.stringify(weights);
    console.log("Total weights len: ", weightStr.length);

    console.log(`Set weights`);
    const maxlen = CHUNK_LEN ? parseInt(CHUNK_LEN) : MaxWeightLen; // do not chunk the weights
    const truncateWeights = (_w: ethers.BigNumber[], maxlen: number) => {
        return _w.splice(0, maxlen);
    }
    const checkForDeployedModel = (receipt: ethers.ContractReceipt) => {
        const deployedEvent = receipt.events?.find((event: ethers.Event) => event.event === 'Deployed');
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
                    
                const appendWeightTx = await eai.appendWeights(tokenId, temp, wi, i, gasConfig);
                const receipt = await appendWeightTx.wait(2);
                console.log(`append layer ${getLayerName(i)} #${wi} (${temp.length}) - tx ${appendWeightTx.hash}`);
                
                checkForDeployedModel(receipt);
            }
        }            
    }

    try {
        const tx = await modelReg.safeMint(MODEL_OWNER || signer.address, modelUri, eai.address, {...mintConfig, gasLimit: 1_000_000 });
        const rc = await tx.wait();
        // listen for Transfer event
        const transferEvent = rc.events?.find((event: ethers.Event) => event.event === 'Transfer');
        if (transferEvent != null) {
            const from = transferEvent.args?.from;
            const to = transferEvent.args?.to;
            const tokenId = transferEvent.args?.tokenId;
            console.log("tx:", tx.hash);
            console.log(`Minted new ImageClassifier model, to=${to}, tokenId=${tokenId}`);
        }
        checkForDeployedModel(rc);
    } catch (e) {
        console.error("Error minting model: ", e);
        throw e;
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { ethers, utils } from "ethers";
import path from 'path';
import levenshtein from 'js-levenshtein';
import * as EternalAIArtifact from '../artifacts/contracts/EternalAI.sol/EternalAI.json';

const ModelCollectionContractName = "ModelCollection";
const EaiContractName = "EternalAI";

const GasLimit = "9000000000"; // 100 B
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
    
const evalPrice = ethers.utils.parseEther('0.01');
const evalConfig = { value: evalPrice };

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

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

function fuzzyMatch(word: string, dict: string[]): string {
    let bestCand = "", bestDist = -1;
    for(let cand of dict) {
        const dist = levenshtein(word, cand);
        if (bestCand === "" || dist < bestDist) {
            bestCand = cand;
            bestDist = dist;
        }
    }
    return bestCand;
}

function tokenizeWordOnly(text: string): string[] {
    const tokens: string[] = [];
    let word = "";
    for(let c of text) {
        if (c === '\'' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            word += c;
        } else {
            if (word !== "") {
                tokens.push(word);
                word = "";
            }
        }
    }
    return tokens;
}

function replaceMatchedWords(text: string, words: string[], matchedWords: string[]): string {
    let result = "";
    for(let i = 0; i < words.length; ++i) {
        let pos = text.search(words[i]);
        result += text.substring(0, pos) + matchedWords[i];
        text = text.slice(pos + words[i].length);
    }
    return result;
}

function postprocessText(text: string, dict: string[]): string {
    const words = tokenizeWordOnly(text);
    const matchedWords = words.map(word => fuzzyMatch(word, dict));
    const replacedText = replaceMatchedWords(text, words, matchedWords);
    return replacedText;
}

task("eval-img", "evaluate model for each layer")
    .addOptionalParam("img", "image file name", "image.png", types.string)
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("offline", "whether to create tx or not", true, types.boolean)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }

        const c = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddressOf(tokenId);
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
        const pixels = imgArray.map((b: any) =>
            ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

        let numLayers = model[3].length;
        let batchLayerNum = 1;
        let inputs = pixels;
        let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(h), ethers.BigNumber.from(w), ethers.BigNumber.from(3)];
        let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, h, w, 3);
        let x2: ethers.BigNumber[] = [];
        let classsNameRes = "";
        let confidence = ethers.BigNumber.from("0");

        let startTime = new Date().getTime();

        if (taskArgs.offline) {
            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;
    
                console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`);
                // if (x1.length > 0) {
                //     console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
                // }
                // if (x2.length > 0) {
                //     console.log(`x2: (${x2.length})`);
                // }
                    
                [classsNameRes, x1, x2, confidence] = await modelContract.evaluate(tokenId, fromLayerIndex, toLayerIndex, x1, x2, {...gasConfig });
                if (classsNameRes !== "") {
                    console.log("Class name:", classsNameRes);                    
                    console.log("Confidence:", confidence);
                    console.log(x2);
                    // console.log("Confidence:", confidence.div(1e14).toNumber() / 100.0);
                }

                if (toLayerIndex >= numLayers - 1) {
                    break;
                }
            }
        } else {
            for (let i = 0; ; i = i + batchLayerNum) {
                const fromLayerIndex = i;
                const toLayerIndex = i + batchLayerNum - 1;
    
                console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
                // if (x1.length > 0) {
                //     console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
                // }
                // if (x2.length > 0) {
                //     console.log(`x2: (${x2.length})`);
                // }
    
                const tx: ethers.ContractTransaction = await measureTime(async () => {
                    return await modelContract.classify(tokenId, fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig, ...gasConfig });
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
                    console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs2 });
                    x1 = outputs1;
                    x2 = outputs2;
                } else if (classifiedEvent) {
                    const tokenId = classifiedEvent.args?.tokenId;
                    const classIndex = classifiedEvent.args?.classIndex;
                    const className = classifiedEvent.args?.className;
                    const outputs = classifiedEvent.args?.outputs;
                    const confidence = classifiedEvent.args?.confidence;
                    console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs, confidence });
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

task("generate-text", "generate text from RNN model")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("prompt", "input prompt", "", types.string)
    .addOptionalParam("togenerate", "number of characters to be generated", 100, types.int)
    .addOptionalParam("generatepertx", "number of characters to generate per tx", -1, types.int)
    .addOptionalParam("offline", "whether to create tx or not", true, types.boolean)
    .addOptionalParam("dictionary", "dictionary for fuzzy match post processing", "", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }

        let prompt = taskArgs.prompt;
        const toGenerate = taskArgs.togenerate;
        const generatePerTx = (taskArgs.generatepertx == -1) ? toGenerate : taskArgs.generatepertx;

        const c = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddressOf(tokenId);
        const modelContract = await ethers.getContractAt(EaiContractName, modelAddress, signer);

        let startTime = new Date().getTime();
        let result = "";
        let seed = ethers.BigNumber.from("123");
        let text;

//         result = `
// No, sir, I will not?

// CATESBY:
// Ay, and you thought
// I think it on the duke stink in my staying like to the humoulches with gentlemen o' the contract in her,
// And say one that had woney to his parts.
// `

        let states: ethers.BigNumber[][][] = [];
        for(let i = 0; i < toGenerate; i += generatePerTx) {
            const generate = Math.min(toGenerate - i, generatePerTx);
            console.log(`Generating characters ${i+1}-${i+generate}`);

            if (taskArgs.offline) {
                [text, states, seed] = await modelContract.generateTextNoTx(tokenId, prompt, generate, states, seed, gasConfig);
            } else {            
                const tx = await modelContract.generateText(tokenId, prompt, generate, states, seed, gasConfig);
                const rc = await tx.wait();
                console.log(`Tx: ${tx.hash}, used gas: ${rc.gasUsed}`);
                
                const textGeneratedEvent = rc.events?.find(event => event.event === 'TextGenerated');                
                if (textGeneratedEvent) {
                    text = textGeneratedEvent.args?.result;
                    states = textGeneratedEvent.args?.states;
                    seed = textGeneratedEvent.args?.seed;
                } else {
                    console.log("TextGenerated event not found");
                    return;
                } 
            }

            // console.log(text);
            // console.log(states);
            // console.log(seed);
    
            result += text;
            prompt = text.slice(text.length - 1);
        }

        console.log("-------------- Prompt + Generated text --------------");
        console.log(taskArgs.prompt + result);
        if (taskArgs.dictionary) {            
            const dict: string[] = JSON.parse(fs.readFileSync(taskArgs.dictionary, 'utf-8'));
            console.log("------------  Prompt + Postprocessed text ----------");
            console.log(taskArgs.prompt + postprocessText(result, dict));
        }
        console.log("----------------------------------------------------");

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / (1000));
    });

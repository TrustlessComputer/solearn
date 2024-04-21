// import { task, types } from "hardhat/config";

// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import fs from 'fs';
// import sharp from 'sharp';
// import { ethers, utils } from "ethers";
// import path from 'path';
// import { getLayerName } from "./lib/modelLib";
// import { getModelDirents, pixelsToImage, measureTime, postprocessText } from "./lib/utils";
// import { runeToText, isRune } from "./rune.task";

// const EternalAIContractName = "EternalAI";
// const ModelRegContractName = "ModelReg";
// const MaxWeightLen = 1000;
// const MaxLayerType = 9;

// const GasLimit = "90000000000"; // 100 B
// const MaxFeePerGas = "1001000000";  // 1e-5 gwei
// const MaxPriorityFeePerGas = "1000000000";
// // const GasLimit = "290000000"; // 100 M
// // const MaxFeePerGas = "10010";  // 1e-5 gwei
// // const MaxPriorityFeePerGas = "10000";
// const gasConfig = {
//     gasLimit: GasLimit,
//     maxPriorityFeePerGas: MaxPriorityFeePerGas,
//     maxFeePerGas: MaxFeePerGas,
// };
    
// const mintPrice = ethers.utils.parseEther('0.1');
// const mintConfig = { value: mintPrice };

// const evalPrice = ethers.utils.parseEther('0.01');
// const evalConfig = { value: evalPrice };

// // task("mint-models", "mint multiple model in a folder (with their weights)")
// //     .addOptionalParam("contract", "contract address", "", types.string)
// //     .addOptionalParam("folder", "folder path", "", types.string)
// //     .addOptionalParam("maxlen", "max length for weights/tx", MaxWeightLen, types.int)
// //     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
// //         const { ethers, deployments, getNamedAccounts } = hre;
// //         const { deployer: signerAddress } = await getNamedAccounts();
// //         const signer = await ethers.getSigner(signerAddress);

// //         const folder = taskArgs.folder;
// //         const modelDirents = await getModelDirents(folder);
        
// //         const models = modelDirents.map((dirent, index) => ({
// //             name: path.basename(dirent.name, '.json'),
// //             path: path.join(folder, dirent.name),
// //         }));

// //         const modelInfos = [];
// //         for(const model of models) {
// //             console.log("Minting model:", model.name);
// //             await hre.run("mint-model-id", {
// //                 model: model.path, 
// //                 contract: taskArgs.contract,
// //                 maxlen: taskArgs.maxlen,
// //             });
// //             const address: string = JSON.parse(fs.readFileSync("model_address.json", 'utf-8'));
// //             const c = await ethers.getContractAt(ModelRegContractName, address, signer);
// //             const modelId = await c.modelId();
        
// //             modelInfos.push({
// //                 name: model.name,
// //                 id: modelId,
// //                 contractAddress: address,
// //             })
// //             fs.writeFileSync("model_list.json", JSON.stringify(modelInfos));
// //         }

// //     });

// task("eval-img", "evaluate model for each layer")
//     .addOptionalParam("img", "image file name", "image.png", types.string)
//     .addOptionalParam("contract", "contract address", "", types.string)
//     .addOptionalParam("id", "token id of model", "1", types.string)
//     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
//         const { ethers, deployments, getNamedAccounts } = hre;
//         const { deployer: signerAddress } = await getNamedAccounts();
//         const signer = await ethers.getSigner(signerAddress);

//         let contractAddress = taskArgs.contract;
//         if (contractAddress === "") {
//             const baseContract = await deployments.get(ModelRegContractName);
//             contractAddress = baseContract.address;
//         }

//         const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
//         const tokenId = ethers.BigNumber.from(taskArgs.id);
//         const modelAddress = await modelRegContract.modelAddr(tokenId);
//         const modelContract = await ethers.getContractAt(EternalAIContractName, modelAddress, signer);

//         const imgRaw = fs.readFileSync(taskArgs.img);
//         console.log("imgRaw: ", imgRaw);
//         // TODO: Get inputDim from EternalAI and use the width and height from inputDim instead
//         // How to get input image size?

//         const model = await modelContract.getInfo();
//         const inputDim = model[0];
//         if (inputDim.length < 2) {
//             throw new Error("Invalid model input dim");
//         }
//         const h = inputDim[0].toNumber();
//         const w = inputDim[1].toNumber();

//         const img = sharp(imgRaw);
//         // const metadata = await img.metadata(); 
//         // const w = metadata.width;
//         // const h = metadata.height;
//         // if (!w || !h) {
//         //     console.log('width and height metadata not found');
//         //     return;
//         // }

//         const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
//         const imgArray = [...imgBuffer];
//         const pixels = imgArray.map((b: any) =>
//             ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

//         let numLayers = model[3].length;
//         let batchLayerNum = 1;
//         let inputs = pixels;
//         let dim: [ethers.BigNumber, ethers.BigNumber, ethers.BigNumber] = [ethers.BigNumber.from(h), ethers.BigNumber.from(w), ethers.BigNumber.from(3)];
//         let x1: ethers.BigNumber[][][] = pixelsToImage(pixels, h, w, 3);
//         let x2: ethers.BigNumber[] = [];
//         let classsNameRes = "";
//         let confidence = ethers.BigNumber.from("0");

//         let startTime = new Date().getTime();

//         for (let i = 0; ; i = i + batchLayerNum) {
//             const fromLayerIndex = i;
//             const toLayerIndex = i + batchLayerNum - 1;

//             console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
//             if (x1.length > 0) {
//                 console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
//             }
//             if (x2.length > 0) {
//                 console.log(`x2: (${x2.length})`);
//             }

//             const tx: ethers.ContractTransaction = await measureTime(async () => {
//                 return await modelContract.classify(tokenId, fromLayerIndex, toLayerIndex, x1, x2, {...evalConfig, ...gasConfig });
//             });

//             console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
//             const receipt = await tx.wait(1);

//             console.log(`Used gas: `, receipt.gasUsed);

//             const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
//             const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
//             if (forwardedEvent) {
//                 const tokenId = forwardedEvent.args?.tokenId;
//                 const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
//                 const toLayerIndex = forwardedEvent.args?.toLayerIndex;
//                 const outputs1 = forwardedEvent.args?.outputs1;
//                 const outputs2 = forwardedEvent.args?.outputs2;
//                 console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs2 });
//                 x1 = outputs1;
//                 x2 = outputs2;
//             } else if (classifiedEvent) {
//                 const tokenId = classifiedEvent.args?.tokenId;
//                 const classIndex = classifiedEvent.args?.classIndex;
//                 const className = classifiedEvent.args?.className;
//                 const outputs = classifiedEvent.args?.outputs;
//                 const confidence = classifiedEvent.args?.confidence;
//                 console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs, confidence });
//                 classsNameRes = className;
//             }

//             if (toLayerIndex >= numLayers - 1) {
//                 break;
//             }
//         }                

//         let endTime = new Date().getTime();
//         console.log("Time: ", (endTime - startTime) / (60 * 1000));
//     });

// task("generate-text", "generate text from RNN model")
//     .addOptionalParam("contract", "contract address", "", types.string)
//     .addOptionalParam("id", "token id of model", "1", types.string)
//     .addOptionalParam("prompt", "input prompt", "", types.string)
//     .addOptionalParam("togenerate", "number of characters to be generated", 100, types.int)
//     .addOptionalParam("generatepertx", "number of characters to generate per tx", -1, types.int)
//     .addOptionalParam("dictionary", "dictionary for fuzzy match post processing", "", types.string)
//     .addOptionalParam("debugpath", "path to save tensors for debug", "", types.string)
//     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
//         const { ethers, deployments, getNamedAccounts } = hre;
//         const { deployer: signerAddress } = await getNamedAccounts();
//         const signer = await ethers.getSigner(signerAddress);

//         let contractAddress = taskArgs.contract;
//         if (contractAddress === "") {
//             const baseContract = await deployments.get(ModelRegContractName);
//             contractAddress = baseContract.address;
//         }

//         let prompt = taskArgs.prompt;
//         const toGenerate = taskArgs.togenerate;
//         const generatePerTx = (taskArgs.generatepertx == -1) ? toGenerate : taskArgs.generatepertx;

//         const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
//         const tokenId = ethers.BigNumber.from(taskArgs.id);
//         const modelAddress = await modelRegContract.modelAddr(tokenId);
//         const modelContract = await ethers.getContractAt(EternalAIContractName, modelAddress, signer);

//         let startTime = new Date().getTime();
//         let seed = ethers.BigNumber.from("123");
//         let states: ethers.BigNumber[][][] = [];

//         // Processing prompt
//         for(let i = 0; i < prompt.length - 1; i += generatePerTx) {
//             const generate = Math.min(prompt.length - 1 - i, generatePerTx);
//             console.log(`Processing prompt ${i+1}-${i+generate}`);
            
//             // console.log(prompt.substr(i, generate));

//             const tx = await modelContract.generateText(tokenId, prompt.substr(i, generate) + "[UNK]", 0, states, seed, gasConfig);
//             const rc = await tx.wait();

//             const textGeneratedEvent = rc.events?.find(event => event.event === 'TextGenerated');
//             if (textGeneratedEvent) {
//                 states = textGeneratedEvent.args?.states;
//                 seed = textGeneratedEvent.args?.seed;
//             }
    
//             console.log(`Used gas: `, rc.gasUsed);
//         }

//         prompt = prompt.slice(prompt.length - 1);
//         console.log(prompt);
//         let result = "";
//         let text;
// //         result = `
// // No, sir, I will not?

// // CATESBY:
// // Ay, and you thought
// // I think it on the duke stink in my staying like to the humoulches with gentlemen o' the contract in her,
// // And say one that had woney to his parts.
// // `

//         // Generating text
//         for(let i = 0; i < toGenerate; i += generatePerTx) {
//             const generate = Math.min(toGenerate - i, generatePerTx);
//             console.log(`Generating characters ${i+1}-${i+generate}`);

//             const tx = await modelContract.generateText(tokenId, prompt, generate, states, seed, gasConfig);
//             const rc = await tx.wait();

//             const textGeneratedEvent = rc.events?.find(event => event.event === 'TextGenerated');
//             if (textGeneratedEvent) {
//                 text = textGeneratedEvent.args?.result;
//                 states = textGeneratedEvent.args?.states;
//                 seed = textGeneratedEvent.args?.seed;
//             }
    
//             result += text;
//             prompt = text.slice(text.length - 1);
//             console.log(`Used gas: `, rc.gasUsed);

//             // const testRNNOutputEvents = rc.events?.filter(event => event.event === 'TestRNNOutput').map(event => event.args.data).map(arr => recursiveToString(arr));
//             // const testEntropyEvents = rc.events?.filter(event => event.event === 'TestEntropy').map(event => event.args.data).map(arr => recursiveToString(arr));
//             // const testProbsEvents = rc.events?.filter(event => event.event === 'TestProbs').map(event => event.args.data).map(arr => recursiveToString(arr));
//             // const testDenseEvents = rc.events?.filter(event => event.event === 'TestDense').map(event => [event.args.x, event.args.w, event.args.tmp, event.args.b, event.args.y, event.args.res]).map(arr => recursiveToString(arr));
    
//             // const testMatmulEvents = rc.events?.filter(event => event.event === 'TestMatMul');
//             // const testMatmulData = testMatmulEvents.map(event => event.args.data);
//             // const testMatmulDec = testMatmulData.map(mat => mat.map(arr => recursiveToString(arr)));
    
//             // if (taskArgs.debugpath !== "") {
//             //     fs.writeFileSync(`${taskArgs.debugpath}_RNNOutput_${i}.json`, JSON.stringify(testRNNOutputEvents));
//             //     fs.writeFileSync(`${taskArgs.debugpath}_Entropy_${i}.json`, JSON.stringify(testEntropyEvents));
//             //     fs.writeFileSync(`${taskArgs.debugpath}_Probs_${i}.json`, JSON.stringify(testProbsEvents));
//             //     fs.writeFileSync(`${taskArgs.debugpath}_Dense_${i}.json`, JSON.stringify(testDenseEvents));
//             //     fs.writeFileSync(`${taskArgs.debugpath}_events_${i}.json`, JSON.stringify(testMatmulDec));    
//             // }
//         }

//         console.log("-------------- Prompt + Generated text --------------");
//         console.log(taskArgs.prompt + result);
//         if (taskArgs.dictionary) {            
//             const dict: string[] = JSON.parse(fs.readFileSync(taskArgs.dictionary, 'utf-8'));
//             console.log("------------  Prompt + Postprocessed text ----------");
//             console.log(taskArgs.prompt + postprocessText(result, dict));
//         } else if (isRune(result)) {
//             console.log("------------  Prompt + Transliterated rune ----------");
//             console.log(runeToText(taskArgs.prompt + result));
//         }
//         console.log("----------------------------------------------------");

//         let endTime = new Date().getTime();
//         console.log("Time: ", (endTime - startTime) / (1000));
//     });

// task("get-model", "get eternal AI model")
//     .addOptionalParam("contract", "contract address", "", types.string)
//     .addOptionalParam("id", "token id", "0", types.string)
//     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
//         const { ethers, deployments } = hre;
//         const [signer] = await ethers.getSigners();
//         let contractAddress = taskArgs.contract;
//         if (contractAddress === "") {
//             const baseContract = await deployments.get(ModelRegContractName);
//             contractAddress = baseContract.address;
//         }
//         const modelRegContract = await ethers.getContractAt(ModelRegContractName, contractAddress, signer);
//         const tokenId = ethers.BigNumber.from(taskArgs.id);
//         const modelAddress = await modelRegContract.modelAddr(tokenId);
//         const modelContract = await ethers.getContractAt(EternalAIContractName, modelAddress, signer);
//         const model = await modelContract.getInfo();

//         fs.writeFileSync("baseDesc.json", JSON.stringify(model));
//         // console.log(JSON.stringify(model));

//         // const lstmInfo = await c.getLSTMLayer(tokenId, ethers.BigNumber.from(0));
//         // const lstmInfoDec = [
//         //     lstmInfo[0].toString(),
//         //     lstmInfo[1].toString(),
//         //     lstmInfo[2].map(numArr => numArr.map(num => num.toString())),
//         //     lstmInfo[3].map(numArr => numArr.map(num => num.toString())),
//         //     lstmInfo[4].map(num => num.toString()),
//         // ]
//         // fs.writeFileSync("lstmInfo.json", JSON.stringify(lstmInfoDec));
//     });

// // task("get-model-ids")
// //     .addOptionalParam("folder", "folder path", "", types.string)
// //     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
// //         const { ethers, deployments, getNamedAccounts } = hre;
// //         const { deployer: signerAddress } = await getNamedAccounts();
// //         const signer = await ethers.getSigner(signerAddress);

// //         const folder = taskArgs.folder;
// //         const modelDirents = await getModelDirents(folder);
        
// //         const models = modelDirents.map((dirent, index) => ({
// //             name: path.basename(dirent.name, '.json'),
// //             id: ethers.BigNumber.from(utils.keccak256(utils.toUtf8Bytes(dirent.name + "v1.0"))).toString(),
// //         }));

// //         fs.writeFileSync("model_list_2.json", JSON.stringify(models));
// //     })

// // task("check-models")
// //     .addOptionalParam("contract", "contract address", "", types.string)
// //     .addOptionalParam("folder", "folder path", "", types.string)
// //     .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
// //         const { ethers, deployments, getNamedAccounts } = hre;
// //         const { deployer: signerAddress } = await getNamedAccounts();
// //         const signer = await ethers.getSigner(signerAddress);
        
// //         const modelRegContract = await ethers.getContractAt(ModelRegContractName, taskArgs.contract, signer);
// //         const modelAddress = await modelRegContract.modelAddr(ethers.BigNumber.from(1));
// //         const modelContract = await ethers.getContractAt(EternalAIContractName, modelAddress, signer);
// //         const folder = taskArgs.folder;
// //         const modelDirents = await getModelDirents(folder);
        
// //         const models = modelDirents.map(dirent => ({
// //             name: path.basename(dirent.name, '.json'),
// //             id: utils.keccak256(utils.toUtf8Bytes(dirent.name + "v1.0")),
// //         }));

// //         for(const model of models) {
// //             const data = await modelContract.getInfo();
// //             if (!data[0][0].eq(ethers.BigNumber.from(24))) {
// //                 console.log(`Model ${model.name} at id ${model.id} not found`);
// //             }
// //         }

// //         fs.writeFileSync("model_list_2.json", JSON.stringify(models));
// //     })

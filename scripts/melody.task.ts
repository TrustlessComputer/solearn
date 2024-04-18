import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import { BigNumber, ethers } from "ethers";
import * as MelodyRNNArtifact from '../artifacts/contracts/MelodyRNN.sol/MelodyRNN.json';

import { execSync } from 'child_process';
import { getLayerType, getActivationType, getPaddingType, getConvSize, getLayerName } from "./utils";

const ModelRegContractName = "ModelReg";
const gasConfig = { gasLimit: 10_000_000_000 };
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

task("generate-melody", "evaluate model for each layer")
    .addOptionalParam("contract", "modelRegistry contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("count", "number of step", 1, types.int)
    .addOptionalParam("steplen", "number of notes to generate per step", 1, types.int)
    .addOptionalParam("output", "output file path", "output.mid", types.string)
    // .addOptionalParam("offline", "evaluate without sending a tx", true, types.boolean)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const inputLen = 20;
        const stepLen = taskArgs.steplen;
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
        const mldy = new ethers.Contract(modelAddress, MelodyRNNArtifact.abi, signer);

        let startTime = new Date().getTime();

        // let rands = [];
        // for (let i = 0; i < inputLen; i++) {
        //     rands.push(Math.floor(Math.random() * 130)); // integers ranged [0,129]
        // }

        let vocabs: ethers.BigNumber[] = await mldy.getVocabs();

        // let rands = [68];
        let rands = [68, 129, 30, 31, 32, 35, 129, 37];
        for (let i = rands.length; i < inputLen; i++) {
            const idx = Math.floor(Math.random() * vocabs.length);
            rands.unshift(vocabs[idx].toNumber()); // integers ranged [0,129]
        }

        console.log(rands);

        let x2 = rands.map(n => ethers.BigNumber.from(String(Math.trunc(n * Math.pow(2, 32)))));
        // console.log("x2:", x2);
        
        let melody: any[] = [];
        for (let i = 0; i < taskArgs.count; i++) {
            // let tx = await mldy.generateMelody(tokenId, stepLen, x2, gasConfig);
            // const rc = await tx.wait();
            // console.log("result:", rc);
            const [res, states] = await mldy.generateMelodyTest(tokenId, stepLen, x2);

            // get event NewMelody
            // const newMelody = rc.events?.find(event => event.event === 'NewMelody');
            // if (newMelody != null) {
                // const res = newMelody.args?.melody;
                const notes = res.map((num: ethers.BigNumber) => Number(num.div(BigNumber.from("18446744073709551616"))))
                // // prevent repetition at the end
                // const last = x2.slice(melody.length-stepLen);
                // let repeated = false;
                // for (let i = 0; i < last.length; i++) {
                //     if (last[i].eq(res[i])) {
                //         repeated = true;
                //         break;
                //     }
                // }
                // if (repeated) { 
                //     res[res.length - 1] = ethers.BigNumber.from(String(Math.trunc(Math.floor(Math.random() * 128) * Math.pow(2, 32))));
                // }
                x2 = x2.concat(res).slice(stepLen);
                melody = melody.concat(notes);
                // sleep for 1s
                await new Promise(r => setTimeout(r, 1000));
            // }
        }
        console.log("generated melody:", melody);

        const cmd = `python scripts/gen_midi.py --data "${JSON.stringify(melody)}" --output-path "${taskArgs.output}"`;
        execSync(cmd);

        let endTime = new Date().getTime();
        console.log("Time: ", (endTime - startTime) / 1000);
    });


task("get-melody-model", "get eternal AI model")
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
        console.log("Reading MelodyRNN model at address", modelAddress);
        const mldy = new ethers.Contract(modelAddress, MelodyRNNArtifact.abi, signer);
        // const model = await mldy.getInfo(tokenId);

        // fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        // console.log(JSON.stringify(model));

        // const lstmInfo = await mldy.getLSTMLayer(ethers.BigNumber.from(2));
        // const lstmInfoDec = [
        //     lstmInfo[0].toString(),
        //     lstmInfo[1].toString(),
        //     lstmInfo[2].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[3].map(numArr => numArr.map(num => num.toString())),
        //     lstmInfo[4].map(num => num.toString()),
        // ]
        // fs.writeFileSync("lstmInfo.json", JSON.stringify(lstmInfoDec));
    });

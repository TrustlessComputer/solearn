import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import { BigNumber, ethers } from "ethers";
import { execSync } from 'child_process';
import { toInt } from "./lib/utils";

const MelodyRNNContractName = "MelodyRNN";
const OnchainModelContractName = "OnchainModel";
const ModelCollectionContractName = "ModelCollection";

async function inferModel(interfaceContract: ethers.Contract, noteCount: number, x: ethers.BigNumber[]) {
    const abic = ethers.utils.defaultAbiCoder;
    const data = abic.encode(
        ["uint256", "int64[]"], 
        [noteCount, x]
    );

    const tx = await interfaceContract.infer(data);
    const rc = await tx.wait();
    
    console.log(`Used gas: `, rc.gasUsed);

    const inferResultEvent = rc.events?.find(event => event.event === 'InferResult');
    if (inferResultEvent) {
        const result = inferResultEvent.args?.result;
        const [ res ] = abic.decode(["int64[]"], result);
        return { res };
    } else {
        console.log("Infer result event not found");
        return {};
    }
}

task("generate-melody", "evaluate model for each layer")
    .addOptionalParam("contract", "ModelCollection contract address", "", types.string)
    .addOptionalParam("id", "token id of model", "1", types.string)
    .addOptionalParam("count", "number of step", 1, types.int)
    .addOptionalParam("steplen", "number of notes to generate per step", 1, types.int)
    .addOptionalParam("output", "output file path", "output.mid", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const inputLen = 20;
        const stepLen = taskArgs.steplen;
        const { ethers, deployments, getNamedAccounts } = hre;
        const { deployer: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }

        const modelCollectionContract = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const interfaceAddress = await modelCollectionContract.modelAddressOf(tokenId);
        const interfaceContract = await ethers.getContractAt(OnchainModelContractName, interfaceAddress, signer);        
        
        const implementAddress = await interfaceContract.implementation();
        const implementContract = await ethers.getContractAt(MelodyRNNContractName, implementAddress, signer);

        let startTime = new Date().getTime();

        // let rands = [];
        // for (let i = 0; i < inputLen; i++) {
        //     rands.push(Math.floor(Math.random() * 130)); // integers ranged [0,129]
        // }

        let vocabs: ethers.BigNumber[] = await implementContract.getVocabs();

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
            const { res } = await inferModel(interfaceContract, stepLen, x2);
            const notes = res.map((num: ethers.BigNumber) => toInt(num).toNumber());
            x2 = x2.concat(res).slice(stepLen);
            melody = melody.concat(notes);
            // sleep for 1s
            await new Promise(r => setTimeout(r, 1000));
        }
        console.log("generated melody:", melody);

        const cmd = `python scripts/gen_midi.py --data "${JSON.stringify(melody)}" --output-path "${taskArgs.output}"`;
        // console.log(cmd);
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
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }
        const modelCollectionContract = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await modelCollectionContract.modelAddressOf(tokenId);
        console.log("Reading MelodyRNN model at address", modelAddress);
        const mldy = await ethers.getContractAt(MelodyRNNContractName, modelAddress, signer);
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

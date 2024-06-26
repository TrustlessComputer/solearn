import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import { BigNumber, ethers } from "ethers";
import * as MelodyRNNArtifact from '../artifacts/contracts/MelodyRNN.sol/MelodyRNN.json';

import { execSync } from 'child_process';

const ModelCollectionContractName = "ModelCollection";
const MaxWeightLen = 1000;
const MaxLayerType = 9;
const gasConfig = { gasLimit: 10_000_000_000 };
const mintPrice = ethers.utils.parseEther('0.1');
const mintConfig = { value: mintPrice };

// model 10x10: MaxWeightLen = 40, numTx = 8, fee = 0.02 * 8 TC

function getLayerType(name: string): number {
    let layerType: number = -1;
    if (name === 'Dense') {
        layerType = 0;
    } else if (name === 'Flatten') {
        layerType = 1;
    } else if (name === 'Rescaling') {
        layerType = 2;
    } else if (name === 'InputLayer') {
        layerType = 3;
    } else if (name === 'MaxPooling2D') {
        layerType = 4;
    } else if (name === 'Conv2D') {
        layerType = 5;
    } else if (name === 'Embedding') {
        layerType = 6;
    } else if (name === 'SimpleRNN') {
        layerType = 7;
    } else if (name === 'LSTM') {
        layerType = 8;
    }
    
    return layerType;
}

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

function getActivationType(name: string): number {
    let activationFn: number = -1;
    if (name === 'leakyrelu') {
        activationFn = 0;
    } else if (name === 'linear' || name === 'softmax') {
        activationFn = 1;
    } else if (name === 'relu') {
        activationFn = 2;
    } else if (name === 'sigmoid') {
        activationFn = 3;
    } else if (name === 'tanh') {
        activationFn = 4;
    }
    return activationFn;
}

function getPaddingType(name: string): number {
    let paddingType: number = -1;
    if (name === "valid") {
        paddingType = 0;
    } else if (name === "same") {
        paddingType = 1;
    }
    return paddingType;
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
    for (let i = 0; i < h; ++i) {
        img.push([]);
        for (let j = 0; j < w; ++j) {
            img[i].push([]);
            for (let k = 0; k < c; ++k) {
                img[i][j].push(pixels[ptr]);
                ++ptr;
            }
        }
    }
    return img;
}

function getConvSize(
    dim: number[],
    size: number[],
    stride: number[],
    padding: string,
): { 
    out: number[], 
    pad: number[] 
} {
    const out = [], pad = [];
    for (let i = 0; i < 2; ++i) {
        if (padding == "same") {
            out.push((dim[i] + stride[i] - 1) / stride[i]);
            const total_pad = (dim[i] % stride[i] == 0) ? Math.max(size[i] - stride[i], 0) : Math.max(size[i] - dim[i] % stride[i], 0);
            pad.push(total_pad / 2);
        } else if (padding == "valid") {
            // TODO: What if dim[i] < size[i]
            out.push((dim[i] - size[i]) / stride[i] + 1);
            pad.push(0);
        }
    }
    return { out, pad };
}

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
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }

        const c = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddressOf(tokenId);
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

        let x2 = rands.map(n => ethers.BigNumber.from(String(Math.trunc(n * 1e18))));
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
                const notes = res.map((num: ethers.BigNumber) => Number(num.div(BigNumber.from("1000000000000000000"))))
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
                //     res[res.length - 1] = ethers.BigNumber.from(String(Math.trunc(Math.floor(Math.random() * 128) * 1e18)));
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
            const baseContract = await deployments.get(ModelCollectionContractName);
            contractAddress = baseContract.address;
        }
        const c = await ethers.getContractAt(ModelCollectionContractName, contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.id);
        const modelAddress = await c.modelAddressOf(tokenId);
        console.log("Reading MelodyRNN model at address", modelAddress);
        const mldy = new ethers.Contract(modelAddress, MelodyRNNArtifact.abi, signer);
        const model = await mldy.getInfo(tokenId);

        // fs.writeFileSync("baseDesc.json", JSON.stringify(model));
        console.log(JSON.stringify(model, null, 2));

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

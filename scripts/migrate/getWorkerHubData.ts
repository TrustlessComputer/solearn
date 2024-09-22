import assert from 'assert';
import { ethers, network } from 'hardhat';
import { ERC721Upgradeable, HybridModel, ModelCollection, WorkerHub } from '../../typechain-types';
import fs from "fs";
import { ceilDiv, saveFile, stringifyJSON, WORKERHUB_ASSIGNMENT_DIR, WORKERHUB_INFERENCE_DIR, WORKERHUB_MINER_DIR, WORKERHUB_UNSTAKE_REQUEST_DIR } from '../lib/lib';
import { Worker, UnstakeRequest, Inference, Assignment } from "./WorkerHubDataObject";

async function getWorkerHubData() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const workerHubAddress = config.workerHubAddress;
    assert.ok(
        workerHubAddress,
        `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
    );

    const workerHub = await ethers.getContractAt("WorkerHub", workerHubAddress);

    const minerAddresses = await workerHub.getMinerAddresses();
    const minerData = await workerHub.getAllMiners();
    saveFile(WORKERHUB_MINER_DIR, `minerData.json`, stringifyJSON(minerData));
    saveFile(WORKERHUB_MINER_DIR, `minerAddresses.json`, stringifyJSON(minerAddresses));

    const unstackRequestData = await workerHub.getAllMinerUnstakeRequests();
    saveFile(WORKERHUB_UNSTAKE_REQUEST_DIR, `unstackRequestData.json`, stringifyJSON(unstackRequestData));

    const count = 1000;

    const inferenceNumber = await workerHub.inferenceNumber();
    const nInferenceFile = ceilDiv(Number(inferenceNumber), count);
    for(let i = 0; i < nInferenceFile; ++i) {
        const startId = i * count + 1;
        const data = await workerHub.getAllInferences(startId, Math.min(count, Number(inferenceNumber) - startId + 1));
        saveFile(WORKERHUB_INFERENCE_DIR, `${i}.json`, stringifyJSON(data));
    }

    const assignmentNumber = await workerHub.assignmentNumber();    
    const nAssignmentFile = ceilDiv(Number(assignmentNumber), count);
    for(let i = 0; i < nAssignmentFile; ++i) {
        const startId = i * count + 1;
        const data = await workerHub.getAllAssignments(startId, Math.min(count, Number(assignmentNumber) - startId + 1));
        saveFile(WORKERHUB_ASSIGNMENT_DIR, `${i}.json`, stringifyJSON(data));
    }
}

getWorkerHubData()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

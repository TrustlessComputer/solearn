import assert from 'assert';
import { ethers, network } from 'hardhat';
import { ERC721Upgradeable, HybridModel, ModelCollection, WorkerHub } from '../typechain-types';
import fs from "fs";
import { saveFile, stringifyJSON } from './lib/lib';

async function getModelsFromCollection() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const collectionAddress = config.collectionAddress;
    assert.ok(
        collectionAddress,
        `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
    );

    const workerHubAddress = config.workerHubAddress;
    assert.ok(
        workerHubAddress,
        `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
    );

    const workerHub = await ethers.getContractAt("WorkerHub", workerHubAddress);

    const minerData = await workerHub.getAllMiners();
    const unstackRequestData = await workerHub.getAllMinerUnstakeRequests();
    const inferenceData = await workerHub.getAllInferences();
    const assignmentData = await workerHub.getAllAssignments();

    const workerHubData = {
        minerData,
        unstackRequestData,
        inferenceData,
        assignmentData,
    };

    saveFile("_outputs", "workerHubData.json", stringifyJSON(workerHubData));
}

getModelsFromCollection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

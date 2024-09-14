import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';
import { WorkerHub } from '../typechain-types';

async function addWorkerToModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHub = await ethers.getContractFactory('WorkerHub');

    const workerHubAddress = config.workerHubAddress;
    assert.ok(
        workerHubAddress,
        `Missing ${networkName}_WORKERHUB_ADDRESS from environment variables!`
    );

    const modelAddress = "0x4A9C36cD5E1D2468d04d9417f8f79C7c1F47a6dE";
    const workerAddresses = [
        "0x4e0d7f17af748f5b1690d25a57a803959839b61a",
        "0xc23a500bb0bd97ddf722941002006530f8b6d8ad",
        "0x3d50f4c69e2be09aea87515d264ea08c8a48157b",
    ];

    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    for(const worker of workerAddresses) {
        await (await workerHub.forceChangeModelForMiner(worker, modelAddress)).wait();
    }
}

addWorkerToModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

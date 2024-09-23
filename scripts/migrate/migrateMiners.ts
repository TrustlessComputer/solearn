import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { HybridModelERC20, ModelCollectionERC20, WorkerHubERC20 } from '../../typechain-types';
import { EventLog, Log } from 'ethers';
import { deployOrUpgrade } from '../lib/utils';
import fs from "fs";
import path from "path";
import { getJsonPathFromDir, MIGRATION_PROGRESS_DIR, stringifyJSON, WORKERHUB_ASSIGNMENT_DIR, WORKERHUB_HYBRID_MODELS_PATH, WORKERHUB_INFERENCE_DIR, readJSONFromFile, WORKERHUB_MINER_DIR } from '../lib/lib';
import { Assignment, Inference, NewInference, Worker, NewWorker } from './WorkerHubDataObject';

async function getDataFromDir(dir: string) {
    const nFiles = (await getJsonPathFromDir(dir)).length;
    const allData = []
    for(let i = 0; i < nFiles; ++i) {
        const data = JSON.parse(fs.readFileSync(path.join(dir, `${i}.json`)).toString())
        allData.push(...data);
    }
    return allData;
}

async function migrateMinersERC20() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHubERC20 = await ethers.getContractFactory('WorkerHubERC20');

    if (!(networkName === "ZK_MAINNET")) {
        console.log("Wrong network:", networkName);
        return;
    }

    const workerHubERC20Address = config.workerHubAddress;
    assert.ok(
        workerHubERC20Address,
        `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
    );
    const workerHubERC20 = await ethers.getContractAt("WorkerHubERC20", workerHubERC20Address);

    const newHybridModelsData = JSON.parse(fs.readFileSync(WORKERHUB_HYBRID_MODELS_PATH).toString());

    const minerDataRaw = await readJSONFromFile(path.join(WORKERHUB_MINER_DIR, "minerData.json"));    
    const minerData = minerDataRaw.map((x: any[]) => Worker.fromArray(x));

    const minerAddresses = await readJSONFromFile(path.join(WORKERHUB_MINER_DIR, "minerAddresses.json"))

    // console.log(minerData.length, minerData[0]);
    // console.log(minerAddresses.length, minerAddresses[0]);

    const newMiner = [];
    for(const data of minerData) {
        const model = newHybridModelsData.find(x => x.oldAddress === data.oldModelAddress);
        if (!model) {
            console.log("Old model address not found:", data.oldModelAddress);
            continue;
        }
        const newModelAddress = model.newAddress;

        newMiner.push({
            stake: data.stake,
            commitment: data.commitment,
            modelAddress: newModelAddress,
            lastClaimedEpoch: data.lastClaimedEpoch,
            activeTime: data.activeTime,
            tier: data.tier,
        });
    }

    // console.log(newMiner[0]);
    
    const progressPath = path.join(MIGRATION_PROGRESS_DIR, "miner.json");
    let migrationStatusData = minerAddresses.map((x: string) => ({ address: x, migrated: false }));    
    if (!fs.existsSync(progressPath)) {
        fs.writeFileSync(progressPath, JSON.stringify(migrationStatusData));
    } else {
        migrationStatusData = await readJSONFromFile(progressPath);
    }

    const migrationStatus = new Map<string, boolean>();
    for(const data of migrationStatusData) {
        migrationStatus.set(data.address, data.migrated);
    }

    const count = 50;
    let txMiner = [], txAddresses = [];
    for(let i = 0; i < newMiner.length; ++i) {
        if (migrationStatus.get(minerAddresses[i])) continue;

        txMiner.push(newMiner[i]);
        txAddresses.push(minerAddresses[i]);

        if (txMiner.length == count || i == newMiner.length - 1) {
            // await (await workerHubERC20.migrateMiner(txAddresses, txMiner)).wait();
            // for(const address of minerAddresses) {
            //     migrationStatus.set(address, true);
            // }
            txMiner = [];
            txAddresses = [];
        }
    }

    console.log(`Migrated ${newMiner.length} Worker to WorkerHubERC20`)
}

migrateMinersERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

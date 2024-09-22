import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { HybridModelERC20, ModelCollectionERC20, WorkerHubERC20 } from '../../typechain-types';
import { EventLog, Log } from 'ethers';
import { deployOrUpgrade } from '../lib/utils';
import fs from "fs";
import path from "path";
import { getJsonPathFromDir, MIGRATION_PROGRESS_DIR, stringifyJSON, WORKERHUB_ASSIGNMENT_DIR, WORKERHUB_HYBRID_MODELS_PATH, WORKERHUB_INFERENCE_DIR, readJSONFromFile } from '../lib/lib';
import { Assignment, Inference, NewInference } from './WorkerHubDataObject';

async function getDataFromDir(dir: string) {
    const nFiles = (await getJsonPathFromDir(dir)).length;
    const allData = []
    for(let i = 0; i < nFiles; ++i) {
        const data = JSON.parse(fs.readFileSync(path.join(dir, `${i}.json`)).toString())
        allData.push(...data);
    }
    return allData;
}

async function migrateInferencesERC20() {
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

    const newHybridModelsData = JSON.parse(fs.readFileSync(WORKERHUB_HYBRID_MODELS_PATH).toString())
    
    const inferenceData = (await getDataFromDir(WORKERHUB_INFERENCE_DIR)).map((x: any[]) => Inference.fromArray(x));
    const assignmentData = (await getDataFromDir(WORKERHUB_ASSIGNMENT_DIR)).map((x: any[]) => Assignment.fromArray(x));

    // console.log(inferenceData.length, inferenceData[0]);
    // console.log(assignmentData.length, assignmentData[0]);
    
    const newInference = [];
    for(const data of inferenceData) {
        const model = newHybridModelsData.find(x => x.oldAddress === data.oldModelAddress);
        if (!model) {
            console.log("Old model address not found:", data.oldModelAddress);
            continue;
        }
        const newModelAddress = model.newAddress;

        newInference.push({
            assignments: data.assignments,
            input: data.input,
            value: data.value,
            disputingAddress: data.disputingAddress,
            modelAddress: newModelAddress,
            expiredAt: data.expiredAt,
            firstSubmissionId: data.firstSubmissionId,
            status: data.status,
            creator: data.creator,
        });
    }
    
    const newAssignment = [];
    for(const data of assignmentData) {        
        newAssignment.push(data);
    }

    const progressPath = path.join(MIGRATION_PROGRESS_DIR, "inference.json");

    let progress = {
        lastMigratedInference: Number(await workerHubERC20.inferenceNumber()) - 1,
        lastMigratedAssignment: Number(await workerHubERC20.assignmentNumber()) - 1,
    }
    // if (!fs.existsSync(progressPath)) {
    //     fs.writeFileSync(progressPath, JSON.stringify(progress));
    // } else {
    //     progress = await readJSONFromFile(progressPath);
    // }

    const count = 50;
    for(let i = progress.lastMigratedInference + 1; i < newInference.length; i += count) {
        const startId = i + 1;
        await (await workerHubERC20.migrateInferenceData(newInference.slice(i, i + count))).wait();
        progress.lastMigratedInference += count;
        fs.writeFileSync(progressPath, JSON.stringify(progress));
        console.log(`Migrated interences with id from ${startId} to ${startId + count - 1}`);

        const nInference = Math.min(newInference.length - i, count);
        const uploadedInferences = await workerHubERC20.getAllInferences(i+1, nInference);
        for(let j = 0; j < nInference; ++j) {
            const inferenceObj = NewInference.fromArray(uploadedInferences[j])
            if (stringifyJSON(inferenceObj) !== stringifyJSON(newInference[i + j])) {
                console.log(`Found different inference at id ${startId + j}. Reverting...`);
                console.log(inferenceObj);
                console.log(newInference[i + j]);
                await (await workerHubERC20.removeInferenceData(nInference)).wait();
                console.log("Reverted");
                return;
            }
        }
    }

    for(let i = progress.lastMigratedAssignment + 1; i < newAssignment.length; i += count) {
        const startId = i + 1;
        await workerHubERC20.migrateAssignmentData(newAssignment.slice(i, i + count));
        progress.lastMigratedAssignment += count;
        fs.writeFileSync(progressPath, JSON.stringify(progress));
        console.log(`Migrated assignments with id from ${startId} to ${startId + count - 1}`);
    }

    console.log(`Migrated ${newInference.length} Inference and ${newAssignment.length} Assignment to WorkerHubERC20`)
}

migrateInferencesERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { HybridModel, ModelCollection, WorkerHub } from '../../typechain-types';
import { EventLog, Log } from 'ethers';
import { deployOrUpgrade } from '../lib/utils';

async function deployHybridModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHub = await ethers.getContractFactory('WorkerHub');
    const ModelCollection = await ethers.getContractFactory('ModelCollection');

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

    const identifier = 0;
    const name = 'Flux V2';
    const minHardware = 1;
    const modelOwnerAddress = '0x248E156B7b14DBFb842a335920d3D85Ca4600812';
    const metadataObj = {
        "version": 1,
        "model_name": "Flux V2",
        "model_type": "image",
        "model_url": "",
        "model_file_hash": "",
        "min_hardware": 1,
        "verifier_url": "",
        "verifier_file_hash": "",
    }
    const metadata = JSON.stringify(metadataObj, null, "\t");
    console.log(metadata);

    const constructorParams = [
        workerHubAddress,
        identifier,
        name,
        metadata
    ];
    const hybridModel = (await deployOrUpgrade(
        null, 
        "HybridModel", 
        constructorParams, 
        config, 
        true
    ) as unknown) as HybridModel;

    console.log(`Contract HybridModel has been deployed to address ${hybridModel.target}`);
    
    const collection = ModelCollection.attach(config.collectionAddress) as ModelCollection;
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModel.target
    )).wait();

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find((event: EventLog) => event.eventName === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }
    
    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    await workerHub.registerModel(hybridModel.target, minHardware, ethers.parseEther('0.2'));

    console.log(`Contract HybridModel is registered to WorkerHub`);
    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.target}`);
}

deployHybridModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

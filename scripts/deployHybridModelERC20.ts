import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { HybridModelERC20, ModelCollectionERC20, WorkerHubERC20 } from '../typechain-types';
import { EventLog, Log } from 'ethers';
import { deployOrUpgrade } from './lib/utils';

async function deployHybridModelERC20() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHubERC20 = await ethers.getContractFactory('WorkerHubERC20');
    const ModelCollectionERC20 = await ethers.getContractFactory('ModelCollectionERC20');

    const collectionAddress = config.collectionAddress;
    assert.ok(
        collectionAddress,
        `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
    );

    const workerHubERC20Address = config.workerHubAddress;
    assert.ok(
        workerHubERC20Address,
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
        workerHubERC20Address,
        identifier,
        name,
        metadata
    ];
    const hybridModelERC20 = (await deployOrUpgrade(
        null, 
        "HybridModelERC20", 
        constructorParams, 
        config, 
        true
    ) as unknown) as HybridModelERC20;

    console.log(`Contract HybridModelERC20 has been deployed to address ${hybridModelERC20.target}`);
    
    const collection = ModelCollectionERC20.attach(config.collectionAddress) as ModelCollectionERC20;
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModelERC20.target,
        0
    )).wait();

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find((event: EventLog) => event.eventName === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }
    
    const workerHubERC20 = WorkerHubERC20.attach(workerHubERC20Address) as WorkerHubERC20;
    await workerHubERC20.registerModel(hybridModelERC20.target, minHardware, ethers.parseEther('0.2'));

    console.log(`Contract HybridModelERC20 is registered to WorkerHubERC20`);

    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModelERC20.target}`);
}

deployHybridModelERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

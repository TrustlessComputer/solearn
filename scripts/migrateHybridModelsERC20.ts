import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { HybridModelERC20, ModelCollectionERC20, WorkerHubERC20 } from '../typechain-types';
import { EventLog, Log } from 'ethers';
import { deployOrUpgrade } from './lib/utils';
import fs from "fs";
import { stringifyJSON } from './lib/lib';

async function migrateHybridModelERC20() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHubERC20 = await ethers.getContractFactory('WorkerHubERC20');
    const ModelCollectionERC20 = await ethers.getContractFactory('ModelCollectionERC20');

    if (!(networkName === "ZK_MAINNET")) {
        console.log("Wrong network:", networkName);
        return;
    }

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

    const hybridModelsData = JSON.parse(fs.readFileSync("_outputs/hybridModelsData.json").toString());
    const newHybridModelsData = JSON.parse(fs.readFileSync("_outputs/newHybridModelsData.json").toString()) as any[];
    for(const { address: oldAddress, tokenId: oldTokenId, name, metadata, owner: modelOwnerAddress } of hybridModelsData) {
        if (newHybridModelsData.find(item => item.oldAddress === oldAddress)) {
            continue;
        }

        const identifier = 0;
        const minHardware = 1;

        const constructorParams = [
            workerHubERC20Address,
            0,
            name,
            metadata
        ];

        // console.log(oldAddress, oldTokenId, name, metadata, modelOwnerAddress);
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
        let newTokenId;
        if (newTokenEvent) {
            newTokenId = newTokenEvent.args?.tokenId;
            console.log("tokenId:", newTokenId);
        }
        
        const workerHubERC20 = WorkerHubERC20.attach(workerHubERC20Address) as WorkerHubERC20;
        await workerHubERC20.registerModel(hybridModelERC20.target, minHardware, ethers.parseEther('0.2'));
    
        console.log(`Contract HybridModelERC20 is registered to WorkerHubERC20`);

        const modelData = {
            oldTokenId,
            oldAddress,
            name,
            metadata,
            modelOwnerAddress,
            newTokenId,
            newAddress: hybridModelERC20.target
        }
        
        newHybridModelsData.push(modelData);
        
        fs.writeFileSync("_outputs/newHybridModelsData.json", stringifyJSON(newHybridModelsData));
    }
}

migrateHybridModelERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

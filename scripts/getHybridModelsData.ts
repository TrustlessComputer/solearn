import assert from 'assert';
import { ethers, network } from 'hardhat';
import { ERC721Upgradeable, HybridModel, ModelCollection, WorkerHub } from '../typechain-types';
import fs from "fs";
import { stringifyJSON } from './lib/lib';

async function getModelsFromCollection() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const HybridModel = await ethers.getContractFactory('HybridModel');

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

    const collection = await ethers.getContractAt("ModelCollection", collectionAddress);
    const workerHub = await ethers.getContractAt("WorkerHub", workerHubAddress);

    // const models = [];
    // let startId = 1;
    // for(let i = 1; i <= 10; ++i) {        
    //     for(let id = startId + 1; ; ++id) {
    //         const address = await collection.modelAddressOf(id);
    //         if (address !== ethers.ZeroAddress) {                
    //             models.push({
    //                 tokenId: id,
    //                 address,
    //             })
    //         } else {
    //             break;
    //         }
    //     }
    //     startId *= 10;
    // }

    // const hybridModels = [];
    // const hybridModelAddresses = await workerHub.getModelAddresses();
    // for(const hybridModelAddress of hybridModelAddresses) {
    //     const foundItem = models.find((item => item.address === hybridModelAddress));
    //     if (foundItem) {
    //         console.log(foundItem);
    //         hybridModels.push(foundItem);
    //     } else {
    //         console.log("Warning: Hybrid model not found in collection:", hybridModelAddress);
    //     }
    // }

    const hybridModelAddresses = await workerHub.getModelAddresses();

    const hybridModelsData = [];
    for(const address of hybridModelAddresses) {
        const model = HybridModel.attach(address) as HybridModel;
        const tokenId = await model.identifier();
        hybridModelsData.push({
            address,
            tokenId,
            name: await model.name(),
            metadata: await model.metadata(),
            owner: await collection.ownerOf(tokenId)
        })
    }

    if (!fs.existsSync("_outputs")) {
        fs.mkdirSync("_outputs", { recursive: true });
    }
    fs.writeFileSync("_outputs/hybridModelsData.json", stringifyJSON(hybridModelsData));
}

getModelsFromCollection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';
import { ModelCollection, WorkerHub } from '../typechain-types';
import { EventLog, Log } from 'ethers';

async function deployHybridModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const HybridModel = await ethers.getContractFactory('HybridModel');
    const WorkerHub = await ethers.getContractFactory('WorkerHub');
    const ModelCollection = await ethers.getContractFactory('ModelCollection');

    const collectionAddress = config.collectionAddress;
    assert.ok(
        collectionAddress,
        `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
    );

    const workerHubAddress = config.workerHubAddress;
    const identifier = 0;
    const name = 'Llama 3 70B';
    const minHardware = 1;
    const modelOwnerAddress = '0xe7ebeb300dB63a76F26833Fa8C6eDCE062fBe383';
    const metadataObj = {
        "version": 1,
        "model_name": "Llama 3 70B",
        "model_type": "text",
        "model_url": "",
        "model_file_hash": "",
        "min_hardware": 1,
        "verifier_url": "",
        "verifier_file_hash": "",
    }

    const metadata = JSON.stringify(metadataObj, null, "\t");
    console.log(metadata);

    const hybridModel = await upgrades.deployProxy(
        HybridModel,
        [
            workerHubAddress,
            identifier,
            name,
            metadata
        ]
    );
    await hybridModel.waitForDeployment();

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

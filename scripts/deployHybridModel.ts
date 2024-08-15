import assert from 'assert';
import { version } from 'chai';
import { ethers, network, upgrades } from 'hardhat';

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
    const name = 'FluxDev';//`Model ${identifier}`;
    const minHardware = 1;
    const modelOwnerAddress = '0x594e1ca39dd377f45d56e9b76e0Acee3a76f7DFC';
    const metadataObj = {
        "version": 1,
        "model_name": "FluxDev",
        "model_type": "image",
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
    await hybridModel.deployed();

    console.log(`Contract HybridModel has been deployed to address ${hybridModel.address}`);

    const collection = ModelCollection.attach(config.collectionAddress);
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModel.address
    )).wait();

    const newTokenEvent = mintReceipt.events?.find((event: ethers.Event) => event.event === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }
    
    const workerHub = WorkerHub.attach(workerHubAddress);
    await workerHub.registerModel(hybridModel.address, minHardware, ethers.utils.parseEther('0.2'));

    console.log(`Contract HybridModel is registered to WorkerHub`);

    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.address}`);
}

deployHybridModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

import assert from 'assert';
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
    const name = 'Animated Concept - SDXL LoRA';//`Model ${identifier}`;
    const minHardware = 1;
    const modelOwnerAddress = '0xBb380912A2E0c83628935f98a5a1b08b8588Ae76';
    const metadata = '{\n' +
        '\t"version": 1,\n' +
        '\t"model_name": "Animated Concept - SDXL LoRA",\n' +
        '\t"model_type": "image",\n' +
        '\t"model_url": "https://gateway.lighthouse.storage/ipfs/QmaG6DJstjfgVuBRDi6Ma66o9SMaReMse1S75nDDwwErM3",\n' +
        '\t"model_file_hash": "dc881c939ff3078b59d9bf2a6fc83db2caf7b0780ee563d3a6fc09ea5a1b35a1",\n' +
        '\t"min_hardware": 1,\n' +
        '\t"verifier_url": "",\n' +
        '\t"verifier_file_hash": ""\n' +
        '}'    

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

    const collection = ModelCollection.attach(config.collectionAddress);
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModel.address
    )).wait();

    const workerHub = WorkerHub.attach(workerHubAddress);
    await workerHub.registerModel(hybridModel.address, minHardware, ethers.utils.parseEther('0.2'));

    console.log(`Contract HybridModel has been deployed to address ${hybridModel.address}`);
    const newTokenEvent = mintReceipt.events?.find((event: ethers.Event) => event.event === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }

    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.address}`);
}

deployHybridModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

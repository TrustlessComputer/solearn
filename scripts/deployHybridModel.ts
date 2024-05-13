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
    const name = 'Fantasy Map';//`Model ${identifier}`;
    const modelOwnerAddress = '0x10919C7A907DAAFcBF581cf5aBBb877DD6675D77';
    const metadata = '{\n' +
        '\t"version": 1,\n' +
        '\t"model_name": "FantasyMap",\n' +
        '\t"model_type": "image",\n' +
        '\t"model_url": "https://gateway.lighthouse.storage/ipfs/Qmaz3AgnZVH1DVqXdciac6G8FUnungDTkBXDo2Dx1FtXx5",\n' +
        '\t"model_file_hash": "2c25f12639d4821f6bb04d853c36a383bd99234b1bb3bcd80e0ac6c98d34247d",\n' +
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
    await workerHub.registerModel(hybridModel.address, 1, ethers.utils.parseEther('0.2'));

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

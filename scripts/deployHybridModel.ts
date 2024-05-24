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
    const name = 'Juggernaut XL';//`Model ${identifier}`;
    const minHardware = 1;
    const modelOwnerAddress = '0xB0D0c3C59B9101D0C98cD2235c03C43F1294cb95';
    const metadata = '{\n' +
        '\t"version": 1,\n' +
        '\t"model_name": "Juggernaut XL",\n' +
        '\t"model_type": "image",\n' +
        '\t"model_url": "https://gateway.lighthouse.storage/ipfs/QmcFYMYpVodkpT6t1fVmWNjPnUnnQbXvwpqyheXvPGKUr8",\n' +
        '\t"model_file_hash": "7f1f29cb884c5b2f4d072b99afcb87f32cbe4adc88cffedab15ffc9fd30887ae",\n' +
        '\t"min_hardware": 1,\n' +
        '\t"verifier_url": "https://gateway.lighthouse.storage/ipfs/QmdkKEjx2fauzbPh1j5bUiQXrUG5Ft36pJGHS8awrN89Dc",\n' +
        '\t"verifier_file_hash": "492b2b3dea3003d359fe1b2cee77a22777d8a9faf942ab6dee81e6bfadaadec4"\n' +
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

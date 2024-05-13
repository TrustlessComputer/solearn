import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';

async function updateHybridModelMetadata() {
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

    const tokenId = 1000001;
    const metadata = '{\n' +
        '\t"version": 1,\n' +
        '\t"model_name": "Max Multi",\n' +
        '\t"model_type": "image",\n' +
        '\t"model_url": "https://gateway.lighthouse.storage/ipfs/QmcFYMYpVodkpT6t1fVmWNjPnUnnQbXvwpqyheXvPGKUr8",\n' +
        '\t"model_file_hash": "7f1f29cb884c5b2f4d072b99afcb87f32cbe4adc88cffedab15ffc9fd30887ae",\n' +
        '\t"min_hardware": 1,\n' +
        '\t"verifier_url": "https://gateway.lighthouse.storage/ipfs/QmdkKEjx2fauzbPh1j5bUiQXrUG5Ft36pJGHS8awrN89Dc",\n' +
        '\t"verifier_file_hash": "492b2b3dea3003d359fe1b2cee77a22777d8a9faf942ab6dee81e6bfadaadec4"\n' +
        '}'

    const collection = ModelCollection.attach(config.collectionAddress);
    await (await collection.updateTokenURI(tokenId, metadata)).wait();
    console.log("TokenURI updated");

    const modelAddress = await collection.modelAddressOf(tokenId);
    const hybridModel = HybridModel.attach(modelAddress);
    await (await hybridModel.updateMetadata(metadata)).wait();
    console.log("Hybrid model metadata updated"); 
}

updateHybridModelMetadata()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

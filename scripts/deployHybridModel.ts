import { ethers, network, upgrades } from 'hardhat';

async function deployHybridModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const HybridModel = await ethers.getContractFactory('HybridModel');
    const WorkerHub = await ethers.getContractFactory('WorkerHub');

    const workerHubAddress = config.workerHubAddress;
    const identifier = 0;
    const name = 'Max Multi';//`Model ${identifier}`;
    const metadata = '{\n' +
        '\t"version": 1,\n' +
        '\t"model_name": "MaxMulti",\n' +
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

    const workerHub = WorkerHub.attach(workerHubAddress);
    await workerHub.registerModel(hybridModel.address, 1, ethers.utils.parseEther('100'));

    console.log(`Contract HybridModel has been deployed to address ${hybridModel.address}`);

    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.address}`);
}

deployHybridModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

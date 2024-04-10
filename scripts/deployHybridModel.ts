import { ethers, network, upgrades } from 'hardhat';

async function deployHybridModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const HybridModel = await ethers.getContractFactory('HybridModel');
    const WorkerHub = await ethers.getContractFactory('WorkerHub');

    const workerHubAddress = config.workerHubAddress;
    const identifier = 3;
    const name = `Model ${identifier}`;
    const url = `abc.com/${identifier}`;
    const inferenceCost = ethers.utils.parseEther('1');

    const hybridModel = await upgrades.deployProxy(
        HybridModel,
        [
            workerHubAddress,
            identifier,
            name,
            url,
            inferenceCost
        ]
    );
    await hybridModel.deployed();

    const workerHub = WorkerHub.attach(workerHubAddress);
    await workerHub.registerModel(hybridModel.address);

    console.log(`Contract HybridModel has been deployed to address ${hybridModel.address}`);

    console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.address}`);
}

deployHybridModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

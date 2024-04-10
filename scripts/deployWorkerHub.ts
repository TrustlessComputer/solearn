import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';

async function deployWorkerHub() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHub = await ethers.getContractFactory('WorkerHub');
    const workerHubAddress = config.workerHubAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.workerHubAddress,
                WorkerHub,
            );
            console.log(`Contract WorkerHub has been updated to address ${config.workerHubAddress}`);
            return config.workerHubAddress;
        })() :
        await (async () => {
            const treasuryAddress = config.treasuryAddress;
            assert.ok(
                treasuryAddress,
                `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
            );

            const collectionAddress = config.collectionAddress || ethers.constants.AddressZero;

            const feePercentage = 10;
            const royaltyPercentage = 20;
            const minimumStake = ethers.constants.WeiPerEther;
            const stakeLockingDuration = 60;


            const workerHub = await upgrades.deployProxy(
                WorkerHub,
                [
                    treasuryAddress,
                    collectionAddress,
                    feePercentage,
                    royaltyPercentage,
                    minimumStake,
                    stakeLockingDuration
                ]
            );
            await workerHub.deployed();
            console.log(`Contract WorkerHub has been deployed to address ${workerHub.address}`);
            return workerHub.address;
        })();
    console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHubAddress}`);
}

deployWorkerHub()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

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

            // const collectionAddress = config.collectionAddress || ethers.constants.AddressZero;

            const feePercentage = 10_00;
            const minterMinimumStake = ethers.utils.parseEther("70000");
            const validatorMinimumStake = ethers.utils.parseEther("70000");
            const mintingTimeLimit = 300;
            const minterRequirement = 3;
            const blockPerEpoch = 100;
            const rewardPerEpochBasedOnPerf = ethers.utils.parseEther("0.5");
            const unstakeDelayTime = 12 * 24 * 3600;

            const workerHub = await upgrades.deployProxy(
                WorkerHub,
                [
                    treasuryAddress,
                    feePercentage,
                    minterMinimumStake,
                    validatorMinimumStake,
                    mintingTimeLimit,
                    minterRequirement,
                    blockPerEpoch,
                    rewardPerEpochBasedOnPerf,
                    unstakeDelayTime
                ]
            );
            await workerHub.deployed();

            await (await workerHub.setNewRewardInEpoch(ethers.utils.parseEther('1'))).wait();

            const tx = {
                to: workerHub.address,
                value: ethers.utils.parseEther('1000')
            }

            await (await ethers.getSigners())[0].sendTransaction(tx);

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

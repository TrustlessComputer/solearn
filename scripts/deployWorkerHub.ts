import assert from "assert";
import { ethers, network, upgrades } from "hardhat";

async function deployWorkerHub() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const workerHubAddress = config.workerHubAddress
    ? await (async () => {
        await upgrades.upgradeProxy(config.workerHubAddress, WorkerHub);
        console.log(
          `Contract WorkerHub has been updated to address ${config.workerHubAddress}`
        );
        return config.workerHubAddress;
      })()
    : await (async () => {
        const treasuryAddress = "0x451064E5B968858cD54f227Dba7b7F419eAC5BA9";
        const feePercentage = 10_00;
        const minerMinimumStake = ethers.utils.parseEther("25000");
        const validatorMinimumStake = ethers.utils.parseEther("40000");
        const miningTimeLimit = 10 * 60;
        const minerRequirement = 3;
        const blockPerEpoch = 600;
        const rewardPerEpochBasedOnPerf = ethers.utils.parseEther("0");
        const rewardPerEpoch = ethers.utils.parseEther("0");
        const unstakeDelayTime = 21 * 24 * 3600;
        const penaltyDuration = 3600;
        const finePercentage = 5_00;

        const workerHub = await upgrades.deployProxy(WorkerHub, [
          treasuryAddress,
          feePercentage,
          minerMinimumStake,
          validatorMinimumStake,
          miningTimeLimit,
          minerRequirement,
          blockPerEpoch,
          rewardPerEpochBasedOnPerf,
          rewardPerEpoch,
          unstakeDelayTime,
          penaltyDuration,
          finePercentage,
        ]);
        await workerHub.deployed();

        // const tx = {
        //     to: workerHub.address,
        //     value: ethers.utils.parseEther('1000')
        // }
        //
        // await (await ethers.getSigners())[0].sendTransaction(tx);

        console.log(
          `Contract WorkerHub has been deployed to address ${workerHub.address}`
        );
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

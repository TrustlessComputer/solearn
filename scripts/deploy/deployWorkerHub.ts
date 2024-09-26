import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployWorkerHub() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  
  const treasuryAddress = config.treasuryAddress;
  assert.ok(
      treasuryAddress,
      `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
  );
  const feePercentage = 10_00;
  const minerMinimumStake = ethers.parseEther("25000");
  const validatorMinimumStake = ethers.parseEther("40000");
  const miningTimeLimit = 10 * 60;
  const minerRequirement = 3;
  const blockPerEpoch = 600;
  const rewardPerEpochBasedOnPerf = ethers.parseEther("0");
  const rewardPerEpoch = ethers.parseEther("0");
  const unstakeDelayTime = 21 * 24 * 3600;
  const penaltyDuration = 3600;
  const finePercentage = 5_00;

  const constructorParams = [
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
  ];

  const workerHub = (await deployOrUpgrade(
    config.workerHubAddress, 
    "WorkerHub", 
    constructorParams, 
    config, 
    true
  ) as unknown) as WorkerHub;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHub.target}`);
}

deployWorkerHub()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

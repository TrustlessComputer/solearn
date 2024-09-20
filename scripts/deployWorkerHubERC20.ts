import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHubERC20 } from "../typechain-types";
import { deployOrUpgrade } from "./lib/utils";

async function deployWorkerHubERC20() {
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
  const unstakeDelayTime = 21 * 24 * 3660;
  const penaltyDuration = 3600;
  const finePercentage = 5_00;
  const stakeToken = "0xCDbE9D69d5d9a98D85384C05b462D16A588B53FA";

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
    stakeToken,
  ];

  const workerHubERC20 = (await deployOrUpgrade(
    config.workerHubAddress, 
    "WorkerHubERC20", 
    constructorParams, 
    config, 
    true
  ) as unknown) as WorkerHubERC20;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHubERC20.target}`);
}

deployWorkerHubERC20()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

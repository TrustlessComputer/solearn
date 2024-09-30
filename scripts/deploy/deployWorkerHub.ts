import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployWorkerHub() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const l2OwnerAddress = config.l2OwnerAddress;
  const treasuryAddress = config.treasuryAddress;
  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
  );
  const feeL2Percentage = 10_00;
  const feeTreasuryPercentage = 30_00;
  const minerMinimumStake = ethers.parseEther("0.1");
  const minerRequirement = 3;
  const blockPerEpoch = 600;
  const rewardPerEpoch = ethers.parseEther("0");
  const submitDuration = 10 * 60;
  const commitDuration = 10 * 60;
  const revealDuration = 10 * 60;
  const unstakeDelayTime = 10 * 60;
  const penaltyDuration = 3600;
  const finePercentage = 5_00;
  const feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )

  const constructorParams = [
    l2OwnerAddress,
    treasuryAddress,
    feeL2Percentage,
    feeTreasuryPercentage,
    minerMinimumStake,
    minerRequirement,
    blockPerEpoch,
    rewardPerEpoch,
    submitDuration,
    commitDuration,
    revealDuration,
    unstakeDelayTime,
    penaltyDuration,
    finePercentage,
    feeRatioMinerValidator,
  ];

  const workerHub = (await deployOrUpgrade(
    config.workerHubAddress,
    "WorkerHub",
    constructorParams,
    config,
    true
  )) as unknown as WorkerHub;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHub.target}`);
}

deployWorkerHub()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

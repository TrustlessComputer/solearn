import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { IWorkerHub, WorkerHubScoring } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";
import { combineDurations } from "../utils";

async function deployWorkerHubScoring() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const l2OwnerAddress = config.l2OwnerAddress;
  const treasuryAddress = config.treasuryAddress;
  const daoTokenAddress = config.daoTokenAddress;
  const workerHubAddress = config.workerHubAddress;
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
  );
  assert.ok(
    daoTokenAddress,
    `Missing ${networkName}_DAO_TOKEN_ADDRESS from environment variables!`
  );
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const feeL2Percentage = 0;
  const feeTreasuryPercentage = 100_00;
  const minerMinimumStake = ethers.parseEther("25000");
  const minerRequirement = 3;
  const blockPerEpoch = 600 * 2;
  const rewardPerEpoch = ethers.parseEther("0.38"); //ethers.parseEther("0.6659");
  const submitDuration = 10 * 6 * 5;
  const commitDuration = 10 * 6 * 5;
  const revealDuration = 10 * 6 * 5;
  const unstakeDelayTime = 1814400; // NOTE:  1,814,400 blocks = 21 days
  const penaltyDuration = 0; // NOTE: 3.3 hours
  const finePercentage = 0;
  const feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const minFeeToUse = ethers.parseEther("0");
  const daoTokenReward = ethers.parseEther("0"); //
  const daoTokenPercentage: IWorkerHub.DAOTokenPercentageStruct = {
    minerPercentage: 50_00,
    userPercentage: 30_00,
    referrerPercentage: 5_00,
    refereePercentage: 5_00,
    l2OwnerPercentage: 10_00,
  };

  const duration = combineDurations(
    submitDuration,
    commitDuration,
    revealDuration,
    unstakeDelayTime,
    penaltyDuration
  );

  const constructorParams = [
    l2OwnerAddress,
    treasuryAddress,
    daoTokenAddress,
    feeL2Percentage,
    feeTreasuryPercentage,
    minerMinimumStake,
    minerRequirement,
    blockPerEpoch,
    rewardPerEpoch,
    duration,
    finePercentage,
    feeRatioMinerValidator,
    minFeeToUse,
    daoTokenReward,
    daoTokenPercentage,
  ];

  const workerHubScoring = (await deployOrUpgrade(
    config.workerHubScoringAddress,
    "WorkerHubScoring",
    constructorParams,
    config,
    true
  )) as unknown as WorkerHubScoring;

  const workerHubScoringAddress = workerHubScoring.target;

  if (!config.workerHubScoringAddress) {
    const WorkerHubScoring = await ethers.getContractFactory(
      "WorkerHubScoring"
    );

    const workerHubScoring = WorkerHubScoring.attach(
      workerHubScoringAddress
    ) as WorkerHubScoring;

    // WorkerHubScoring setupScoringVar
    const txSetup = await workerHubScoring.setupScoringVar(workerHubAddress);
    const receiptSetup = await txSetup.wait();
    console.log(
      `Contract WorkerHubScoring setup state: ${receiptSetup?.status}`
    );
  }

  console.log(
    `${networkName}_WORKER_HUB_SCORING_ADDRESS=${workerHubScoringAddress}`
  );
}

deployWorkerHubScoring()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

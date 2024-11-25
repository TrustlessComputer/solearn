import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  IWorkerHub,
  StakingHub,
  WorkerHub,
} from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";
import { combineDurations } from "../utils";

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

async function deployWorkerHub() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const l2OwnerAddress = config.l2OwnerAddress;
  const treasuryAddress = config.treasuryAddress;
  const daoTokenAddress = config.daoTokenAddress;
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

  const feeL2Percentage = 0;
  const feeTreasuryPercentage = 100_00;
  const minerMinimumStake = ethers.parseEther("25000");
  const minerRequirement = 3;
  const blockPerEpoch = 600 * 2;
  const rewardPerEpoch = ethers.parseEther("0.38");
  const submitDuration = 10 * 6 * 5;
  const commitDuration = 10 * 6 * 5;
  const revealDuration = 10 * 6 * 5;
  const unstakeDelayTime = 1814400; // NOTE:  1,814,400 blocks = 21 days
  const penaltyDuration = 1200; // NOTE: 3.3 hours
  const finePercentage = 10_00;
  const feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const minFeeToUse = ethers.parseEther("0.1");
  const daoTokenReward = ethers.parseEther("0"); // llama =  10
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

  const workerHub = (await deployOrUpgrade(
    config.workerHubAddress,
    "WorkerHub",
    constructorParams,
    config,
    true
  )) as unknown as WorkerHub;

  const workerHubAddress = workerHub.target;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHubAddress}`);

  if (!config.workerHubAddress) {
    const DAOTokenFact = await ethers.getContractFactory("DAOToken");
    const daoToken = DAOTokenFact.attach(daoTokenAddress) as DAOToken;

    const tx = await daoToken.updateWorkerHub(workerHubAddress);
    const receipt = await tx.wait();
    console.log("DAO Token updated Worker Hub address:");
    console.log("Tx hash: ", receipt?.hash);
    console.log("Tx status: ", receipt?.status);
  }
}

deployWorkerHub()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

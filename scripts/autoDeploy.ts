import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { IWorkerHub, WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployToken() {
  const _MAX_SUPPLY_CAP = ethers.parseEther("2_100_000_000"); //2,1B
}

async function deployWorkerHub() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const l2OwnerAddress = config.l2OwnerAddress;
  const treasuryAddress = config.treasuryAddress;
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
  );
  const llama_feeL2Percentage = 0;
  const llama_feeTreasuryPercentage = 100_00;
  const llama_minerMinimumStake = ethers.parseEther("25000");
  const llama_minerRequirement = 3;
  const llama_blockPerEpoch = 600;
  const llama_rewardPerEpoch = ethers.parseEther("0.38");
  const llama_submitDuration = 10 * 6;
  const llama_commitDuration = 10 * 6;
  const llama_revealDuration = 10 * 6;
  const llama_unstakeDelayTime = 10 * 60;
  const llama_penaltyDuration = 1200;
  const llama_finePercentage = 10_00;
  const llama_feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const llama_daoTokenReward = ethers.parseEther("0"); // llama =  10
  const llama_daoTokenPercentage: IWorkerHub.DAOTokenPercentageStruct = {
    minerPercentage: 50_00,
    userPercentage: 30_00,
    referrerPercentage: 5_00,
    refereePercentage: 5_00,
    l2OwnerPercentage: 10_00,
  };

  const llama_constructorParams = [
    l2OwnerAddress,
    treasuryAddress,
    llama_feeL2Percentage,
    llama_feeTreasuryPercentage,
    llama_minerMinimumStake,
    llama_minerRequirement,
    llama_blockPerEpoch,
    llama_rewardPerEpoch,
    llama_submitDuration,
    llama_commitDuration,
    llama_revealDuration,
    llama_unstakeDelayTime,
    llama_penaltyDuration,
    llama_finePercentage,
    llama_feeRatioMinerValidator,
    llama_daoTokenReward,
    llama_daoTokenPercentage,
  ];

  const workerHub = (await deployOrUpgrade(
    config.workerHubAddress,
    "WorkerHub",
    llama_constructorParams,
    config,
    true
  )) as unknown as WorkerHub;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHub.target}`);
}

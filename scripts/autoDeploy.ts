import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  AI721,
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  PromptScheduler,
  SquadManager,
  StakingHub,
  SystemPromptManager,
  Treasury,
  WorkerHub,
  WrappedEAI,
} from "../typechain-types";
import { deployContract, deployOrUpgrade } from "./lib/utils";
import { EventLog, Signer } from "ethers";
import path from "path";
import fs from "fs";
import { SystemPromptHelper } from "../typechain-types/contracts/lib/SystemPromptHelper";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployWrappedEAI() {
  console.log("DEPLOY WEAI...");
  let wEAIAddress = "";

  if (config.zksync) {
    const ins = (await deployContract("WrappedEAI", [], {
      noVerify: true,
    })) as unknown as WrappedEAI;

    wEAIAddress = ins.target as string;
  } else {
    const fact = await ethers.getContractFactory("WrappedEAI");
    const ins = (await fact.deploy()) as WrappedEAI;
    await ins.waitForDeployment();

    wEAIAddress = ins.target as string;
  }

  return wEAIAddress;
}

async function deployTreasury(wEAIAddress: string) {
  console.log("DEPLOY TREASURY...");

  assert.ok(wEAIAddress, `Missing ${networkName}_WEAI!`);
  const constructorParams = [wEAIAddress];

  const treasury = (await deployOrUpgrade(
    undefined,
    "Treasury",
    constructorParams,
    config,
    true
  )) as unknown as Treasury;

  return treasury.target;
}

async function deployModelCollection(
  treasuryAddress: string,
  wEAIAddress: string
) {
  console.log("DEPLOY MODEL COLLECTION...");

  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
  );
  assert.ok(
    wEAIAddress,
    `Missing ${networkName}_WEAI from environment variables!`
  );

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = treasuryAddress;
  const royalPortion = 5_00;
  const nextModelId = 130_001; // TODO: @kelvin need to confirm

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    wEAIAddress,
  ];

  const modelCollection = (await deployOrUpgrade(
    undefined,
    "ModelCollection",
    constructorParams,
    config,
    true
  )) as unknown as ModelCollection;

  return modelCollection.target;
}

async function deployStakingHub(
  wEAIAddress: string,
  modelCollectionAddress: string,
  treasuryAddress: string
) {
  console.log("DEPLOY STAKING HUB...");

  assert.ok(
    wEAIAddress,
    `Missing ${networkName}_WEAI from environment variables!`
  );
  assert.ok(
    modelCollectionAddress,
    `Missing ${networkName}_COLLECTION_ADDRESS!`
  );
  assert.ok(treasuryAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

  const minerMinimumStake = ethers.parseEther("25000");
  const blockPerEpoch = 600;
  const rewardPerEpoch = ethers.parseEther("0"); // TODO: @kelvin need to confirm

  // const unstakeDelayTime = 151200; // NOTE:  151200 blocks = 21 days (blocktime = 12)
  const unstakeDelayTime = 907200; // NOTE:  907200 blocks = 21 days (blocktime = 2)
  const penaltyDuration = 0; // NOTE: 3.3 hours
  const finePercentage = 0;
  const minFeeToUse = ethers.parseEther("0");

  const constructorParams = [
    wEAIAddress,
    modelCollectionAddress,
    treasuryAddress,
    minerMinimumStake,
    blockPerEpoch,
    rewardPerEpoch,
    unstakeDelayTime,
    penaltyDuration,
    finePercentage,
    minFeeToUse,
  ];

  const stakingHub = (await deployOrUpgrade(
    undefined,
    "StakingHub",
    constructorParams,
    config,
    true
  )) as unknown as StakingHub;
  const stakingHubAddress = stakingHub.target;

  return stakingHubAddress;
}

async function deployPromptScheduler(
  wEAIAddress: string,
  stakingHubAddress: string
) {
  console.log("DEPLOY PROMPT SCHEDULER...");

  assert.ok(
    wEAIAddress,
    `Missing ${networkName}_WEAI from environment variables!`
  );
  assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);

  const minerRequirement = 3;
  const submitDuration = 10 * 6 * 5;
  const minerValidatorFeeRatio = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const batchPeriod = 24 * 60 * 60; // 24 hours
  const constructorParams = [
    wEAIAddress,
    stakingHubAddress,
    minerRequirement,
    submitDuration,
    minerValidatorFeeRatio,
    batchPeriod,
  ];

  const promptScheduler = (await deployOrUpgrade(
    undefined,
    "PromptScheduler",
    constructorParams,
    config,
    true
  )) as unknown as PromptScheduler;
  const promptSchedulerAddress = promptScheduler.target;

  // Staking Hub update Prompt Scheduler Address
  console.log("STAKING HUB UPDATE PROMPT SCHEDULER ADDRESS...");
  const stakingHubContract = (await getContractInstance(
    stakingHubAddress,
    "StakingHub"
  )) as unknown as StakingHub;

  const txUpdate = await stakingHubContract.setPromptSchedulerAddress(
    promptSchedulerAddress
  );
  const receiptUpdate = await txUpdate.wait();
  console.log("Tx hash: ", receiptUpdate?.hash);
  console.log("Tx status: ", receiptUpdate?.status);

  return promptSchedulerAddress;
}

// async function deploySystemPromptManager(
//   promptSchedulerAddress: string,
//   stakingHubAddress: string,
//   treasureAddress: string
// ) {
//   console.log("DEPLOY SYSTEM PROMPT MANAGER...");

//   assert.ok(
//     promptSchedulerAddress,
//     `Missing ${networkName}_PROMPT_SCHEDULER_ADDRESS!`
//   );
//   assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);
//   assert.ok(treasureAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

//   const name = "Eternal AI";
//   const symbol = "";
//   const mintPrice = ethers.parseEther("0");
//   const royaltyReceiver = treasureAddress;
//   const royalPortion = 5_00;
//   const nextModelId = 1;

//   const constructorParams = [
//     name,
//     symbol,
//     mintPrice,
//     royaltyReceiver,
//     royalPortion,
//     nextModelId,
//     promptSchedulerAddress,
//     stakingHubAddress,
//   ];

//   const systemPromptManager = (await deployOrUpgrade(
//     undefined,
//     "SystemPromptManager",
//     constructorParams,
//     config,
//     true
//   )) as unknown as SystemPromptManager;

//   //
//   // console.log("SYSTEM PROMPT MANAGER SET WORKER HUB ADDRESS...");
//   // const ins = (await getContractInstance(
//   //   config.systemPromptManagerAddress,
//   //   "SystemPromptManager"
//   // )) as SystemPromptManager;
//   // const tx = await ins.setWorkerHub(workerHubAddress);
//   // const receipt = await tx.wait();
//   // console.log("Tx hash: ", receipt?.hash);
//   // console.log("Tx status: ", receipt?.status);

//   return systemPromptManager.target;
// }

async function deployAI721(
  wEAIAddress: string,
  stakingHubAddress: string,
  treasureAddress: string
) {
  console.log("DEPLOY SYSTEM PROMPT MANAGER...");

  assert.ok(wEAIAddress, `Missing ${networkName}_WEAI!`);
  assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);
  assert.ok(treasureAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = treasureAddress;
  const royalPortion = 5_00;
  const nextModelId = 1;
  const tokenFee = wEAIAddress;

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    stakingHubAddress,
    tokenFee,
  ];

  const ai721 = (await deployOrUpgrade(
    undefined,
    "AI721",
    constructorParams,
    config,
    true
  )) as unknown as AI721;
}

// async function deployAI20(
//   wEAIAddress: string,
//   stakingHubAddress: string,
//   treasureAddress: string
// ) {
//   console.log("DEPLOY SYSTEM PROMPT MANAGER...");

//   assert.ok(wEAIAddress, `Missing ${networkName}_WEAI!`);
//   assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);
//   assert.ok(treasureAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

//   const name = "Eternal AI";
//   const symbol = "";
//   const mintPrice = ethers.parseEther("0");
//   const royaltyReceiver = treasureAddress;
//   const royalPortion = 5_00;
//   const nextModelId = 1;
//   const tokenFee = wEAIAddress;

//   const constructorParams = [
//     name,
//     symbol,
//     mintPrice,
//     royaltyReceiver,
//     royalPortion,
//     nextModelId,
//     stakingHubAddress,
//     tokenFee,
//   ];

//   const ai721 = (await deployOrUpgrade(
//     undefined,
//     "AI721",
//     constructorParams,
//     config,
//     true
//   )) as unknown as AI721;
// }

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

async function saveDeployedAddresses(networkName: string, addresses: any) {
  const filePath = path.join(__dirname, `../deployedAddressesV2.json`);
  let data: { [key: string]: any } = {};

  if (fs.existsSync(filePath)) {
    data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  }

  data[networkName] = addresses;

  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function main() {
  const masterWallet = (await ethers.getSigners())[0];
  const deployer = masterWallet.address;

  const wEAIAddress = await deployWrappedEAI();
  const treasuryAddress = await deployTreasury(wEAIAddress.toString());
  const collectionAddress = await deployModelCollection(
    treasuryAddress.toString(),
    wEAIAddress.toString()
  );

  const stakingHubAddress = await deployStakingHub(
    wEAIAddress.toString(),
    collectionAddress.toString(),
    treasuryAddress.toString()
  );
  const promptSchedulerAddress = await deployPromptScheduler(
    wEAIAddress.toString(),
    stakingHubAddress.toString()
  );

  const dagent721 = await deployAI721(
    wEAIAddress.toString(),
    stakingHubAddress.toString(),
    treasuryAddress.toString()
  );

  const deployedAddresses = {
    deployer,
    wEAIAddress,
    treasuryAddress,
    collectionAddress,
    stakingHubAddress,
    promptSchedulerAddress,
    dagent721,
  };

  const networkName = network.name.toUpperCase();

  await saveDeployedAddresses(networkName, deployedAddresses);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

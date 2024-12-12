import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  SquadManager,
  StakingHub,
  SystemPromptManager,
  Treasury,
  WorkerHub,
} from "../typechain-types";
import {
  deployOrUpgrade,
  deployContract,
  DeployContractOptions,
} from "./lib/utils";
import { EventLog, Signer } from "ethers";
import path from "path";
import fs from "fs";
import { get } from "http";
import { AIPoweredWallet } from "../typechain-types/contracts/AIPoweredWallet.sol/AIPoweredWallet";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployAIPoweredWallet() {
  console.log("DEPLOY AI POWERED WALLET...");

  const artifactName = "AIPoweredWallet";
  const opt = {
    noVerify: true,
  } as DeployContractOptions;

  const aiPoweredWallet = await deployContract(artifactName, [], opt);
  console.log("===========DONE===========");

  return aiPoweredWallet.target;
}

async function deployWEAI() {
  console.log("DEPLOY WEAI...");

  const artifactName = "WrappedEAI";
  const opt = {
    noVerify: true,
  } as DeployContractOptions;

  const wEAI = await deployContract(artifactName, [], opt);
  console.log("===========DONE===========");

  return wEAI.target;
}

async function deployStakingHub(
  daoTokenAddress: string,
  treasuryAddress: string,
  wEAIAddress: string
) {
  console.log("DEPLOY STAKING HUB...");

  const l2OwnerAddress = config.l2OwnerAddress;
  // const wEAIAddress = config.wEAIAddress;
  assert.ok(
    wEAIAddress,
    `Missing ${networkName}_WEAI from environment variables!`
  );
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);
  assert.ok(treasuryAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

  const minerMinimumStake = ethers.parseEther("25000");
  const blockPerEpoch = 600 * 2;
  const rewardPerEpoch = ethers.parseEther("0.38");

  // const unstakeDelayTime = 7257600; // NOTE:  7257600 blocks = 21 days (blocktime avg = 0.25) arbitrum
  const unstakeDelayTime = 1814400; // NOTE:  1814400 blocks = 21 days (blocktime avg = 1) zksync
  const penaltyDuration = 0; // NOTE: 3.3 hours
  const finePercentage = 0;
  const minFeeToUse = ethers.parseEther("0");

  const constructorParams = [
    wEAIAddress,
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

  console.log("===========DONE===========");

  return stakingHubAddress;
}

async function deployWorkerHub(
  daoTokenAddress: string,
  treasuryAddress: string,
  stakingHubAddress: string,
  wEAIAddress: string
) {
  console.log("DEPLOY WORKER HUB...");

  const l2OwnerAddress = config.l2OwnerAddress;

  assert.ok(
    wEAIAddress,
    `Missing ${networkName}_WEAI from environment variables!`
  );
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);
  assert.ok(treasuryAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);
  assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);

  const feeL2Percentage = 0;
  const feeTreasuryPercentage = 100_00;
  const minerRequirement = 3;
  const submitDuration = 10 * 6 * 90;
  const commitDuration = 10 * 6 * 90;
  const revealDuration = 10 * 6 * 90;
  const feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const daoTokenReward = ethers.parseEther("0");
  const daoTokenPercentage: IWorkerHub.DAOTokenPercentageStruct = {
    minerPercentage: 50_00,
    userPercentage: 30_00,
    referrerPercentage: 5_00,
    refereePercentage: 5_00,
    l2OwnerPercentage: 10_00,
  };
  const startInferNumber = 40000; // @kelvin review
  const startAssignNumber = (startInferNumber - 1) * 3; // @kelvin review

  const constructorParams = [
    wEAIAddress,
    l2OwnerAddress,
    treasuryAddress,
    daoTokenAddress,
    stakingHubAddress,
    feeL2Percentage,
    feeTreasuryPercentage,
    minerRequirement,
    submitDuration,
    commitDuration,
    revealDuration,
    feeRatioMinerValidator,
    daoTokenReward,
    daoTokenPercentage,
    startInferNumber,
    startAssignNumber,
  ];

  const workerHub = (await deployOrUpgrade(
    undefined,
    "WorkerHub",
    constructorParams,
    config,
    true
  )) as unknown as WorkerHub;
  const workerHubAddress = workerHub.target;

  // DAO TOKEN UPDATE WORKER HUB ADDRESS
  console.log("DAO TOKEN UPDATE WORKER HUB ADDRESS...");
  const daoTokenContract = (await getContractInstance(
    daoTokenAddress,
    "DAOToken"
  )) as unknown as DAOToken;

  const tx = await daoTokenContract.updateWorkerHub(workerHubAddress);
  const receipt = await tx.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);

  // Staking Hub update WorkerHub Address
  console.log("STAKING HUB UPDATE WORKER HUB ADDRESS...");
  const stakingHubContract = (await getContractInstance(
    stakingHubAddress,
    "StakingHub"
  )) as unknown as StakingHub;

  const txUpdate = await stakingHubContract.setWorkerHubAddress(
    workerHubAddress
  );
  const receiptUpdate = await txUpdate.wait();
  console.log("Tx hash: ", receiptUpdate?.hash);
  console.log("Tx status: ", receiptUpdate?.status);

  console.log("===========DONE===========");

  return workerHubAddress;
}

async function registerHybridModels(
  stakingHubAddress: string,
  modelAddresses: string[]
) {
  console.log("STAKING HUB REGISTER MODEL...");

  const StakingHub = await ethers.getContractFactory("StakingHub");

  assert.ok(stakingHubAddress, `Missing ${networkName}_STAKING_HUB_ADDRESS!`);
  assert.ok(modelAddresses.length > 0, `Empty hybridModel addresses!`);

  const minHardware = 1;

  // STAKING HUB REGISTER MODEL
  for await (let hybridModelAddress of modelAddresses) {
    console.log("Registering hybrid model: ", hybridModelAddress);
    const stakingHub = StakingHub.attach(stakingHubAddress) as StakingHub;
    const txRegis = await stakingHub.registerModel(
      hybridModelAddress,
      minHardware,
      ethers.parseEther("0")
    );
    const receipt = await txRegis.wait();
    console.log("Tx hash: ", receipt?.hash);
    console.log("Tx status: ", receipt?.status);
  }
}

async function upgradeSystemPromptManagerAndUpdateWorkerHubAddress(
  l2OwnerAddress: string,
  hybridModelAddress: string,
  workerHubAddress: string
) {
  console.log("DEPLOY SYSTEM PROMPT MANAGER...");

  assert.ok(l2OwnerAddress, `Missing ${networkName}_L2_OWNER_ADDRESS!`);
  assert.ok(hybridModelAddress, `Missing ${networkName}_HYBRID_MODEL_ADDRESS!`);
  assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = l2OwnerAddress;
  const royalPortion = 5_00;
  const nextModelId = 1; //TODO: need to change before deployment

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    hybridModelAddress,
    workerHubAddress,
  ];

  const sysPromptManager = (await deployOrUpgrade(
    config.systemPromptManagerAddress,
    "SystemPromptManager",
    constructorParams,
    config,
    true
  )) as unknown as SystemPromptManager;
  const sysPromptManagerAddr = sysPromptManager.target;

  // SystemPromptManager update Worker Hub Address
  const sysPromptIns = (await getContractInstance(
    sysPromptManagerAddr as string,
    "SystemPromptManager"
  )) as unknown as SystemPromptManager;

  console.log("SYSTEM PROMPT MANAGER UPDATE WORKER HUB ADDRESS...");
  const tx = await sysPromptIns.updateWorkerHubAddress(workerHubAddress);
  const receipt = await tx.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);

  console.log("===========DONE===========");

  return sysPromptManagerAddr;
}

async function deploySquadManager(systemPromptManagerAddress: string) {
  console.log("DEPLOY SQUAD MANAGER...");

  assert.ok(
    systemPromptManagerAddress,
    `Missing ${networkName}_SQUAD_MANAGER_ADDRESS!`
  );

  const constructorParams = [systemPromptManagerAddress];

  const squadManager = (await deployOrUpgrade(
    undefined,
    "SquadManager",
    constructorParams,
    config,
    true
  )) as unknown as SquadManager;

  console.log("===========DONE===========");

  return squadManager.target;
}

// ! Critical
async function hybridModelsUpdateWorkerHub(
  workerHubAddress: string,
  hybridModelAddresses: string[]
) {
  console.log("HYBRID MODEL UPDATE WORKER HUB ADDRESS...");
  console.log("Worker Hub Address: ", workerHubAddress);

  assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);
  assert.ok(
    hybridModelAddresses.length == 4,
    `HybridModel addresses are empty!`
  );

  for await (let hybridModelAddress of hybridModelAddresses) {
    console.log("Hybrid Model Address: ", hybridModelAddress);
    const hybridModelIns = (await getContractInstance(
      hybridModelAddress,
      "HybridModel"
    )) as unknown as HybridModel;

    const tx = await hybridModelIns.updateWorkerHub(workerHubAddress);
    const receipt = await tx.wait();
    console.log("Tx hash: ", receipt?.hash);
    console.log("Tx status: ", receipt?.status);
  }
  console.log("===========DONE===========");
}

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

async function saveDeployedAddresses(networkName: string, addresses: any) {
  const filePath = path.join(__dirname, `../deployedAddresses.json`);
  let data: { [key: string]: any } = {};

  if (fs.existsSync(filePath)) {
    data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  }

  data[networkName] = addresses;

  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function main() {
  const aiPoweredWalletAddress = await deployAIPoweredWallet();
  const wEAIAddress = await deployWEAI();

  const daoTokenAddress = config.daoTokenAddress;
  const treasuryAddress = config.treasuryAddress;

  const stakingHubAddress = await deployStakingHub(
    daoTokenAddress.toString(),
    treasuryAddress.toString(),
    wEAIAddress.toString()
  );
  const workerHubAddress = await deployWorkerHub(
    daoTokenAddress.toString(),
    treasuryAddress.toString(),
    stakingHubAddress.toString(),
    wEAIAddress.toString()
  );
  const collectionAddress = config.collectionAddress;

  const hybridModelAddresses = config.hybridModelAddresses;
  await registerHybridModels(
    stakingHubAddress.toString(),
    hybridModelAddresses
  );

  const systemPromptManagerAddress =
    await upgradeSystemPromptManagerAndUpdateWorkerHubAddress(
      config.l2OwnerAddress,
      hybridModelAddresses[0],
      workerHubAddress.toString()
    );

  const squadManager = await deploySquadManager(
    config.systemPromptManagerAddress
  );

  // ! critical
  // await hybridModelsUpdateWorkerHub(
  //   workerHubAddress.toString(),
  //   hybridModelAddresses
  // );

  const deployedAddresses = {
    aiPoweredWalletAddress,
    wEAIAddress,
    daoTokenAddress,
    treasuryAddress,
    stakingHubAddress,
    workerHubAddress,
    collectionAddress,
    hybridModelAddresses,
    systemPromptManagerAddress,
    squadManager,
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

import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  PromptScheduler,
  SquadManager,
  StakingHub,
  SystemPromptManager,
  Treasury,
} from "../typechain-types";
import { deployOrUpgrade } from "./lib/utils";
import { EventLog, Signer } from "ethers";
import path from "path";
import fs from "fs";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployDAOToken() {
  console.log("DEPLOY DAO TOKEN...");

  const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000"); //2,1B
  const tokenName = "DAOTOKEN";
  const tokenSymbol = "DAOTOKEN";
  const initializedParams = [tokenName, tokenSymbol, _MAX_SUPPLY_CAP];

  const daoToken = (await deployOrUpgrade(
    undefined,
    "DAOToken",
    initializedParams,
    config,
    true
  )) as unknown as DAOToken;

  return daoToken.target;
}

async function deployTreasury(daoTokenAddress: string) {
  console.log("DEPLOY TREASURY...");

  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);
  const constructorParams = [daoTokenAddress];

  const treasury = (await deployOrUpgrade(
    undefined,
    "Treasury",
    constructorParams,
    config,
    true
  )) as unknown as Treasury;

  return treasury.target;
}

async function deployStakingHub(
  daoTokenAddress: string,
  treasuryAddress: string
) {
  console.log("DEPLOY STAKING HUB...");

  const l2OwnerAddress = config.l2OwnerAddress;
  const wEAIAddress = config.wEAIAddress;
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

  // const unstakeDelayTime = 151200; // NOTE:  151200 blocks = 21 days (blocktime = 12)
  // const unstakeDelayTime = 907200; // NOTE:  907200 blocks = 21 days (blocktime = 2s) // Avax
  const unstakeDelayTime = 604800; // NOTE:  604800 blocks = 21 days (blocktime = 3s) // BSC
  // const unstakeDelayTime = 604800; // NOTE:  604800 blocks = 21 days (blocktime = 3s) // TRON
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

  return stakingHubAddress;
}

async function deployWorkerHub(
  daoTokenAddress: string,
  treasuryAddress: string,
  stakingHubAddress: string,
  masterWallet: Signer
) {
  console.log("DEPLOY WORKER HUB...");

  const l2OwnerAddress = config.l2OwnerAddress;
  const wEAIAddress = config.wEAIAddress;
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
    feeRatioMinerValidator,
    daoTokenReward,
    daoTokenPercentage,
  ];

  const workerHub = (await deployOrUpgrade(
    undefined,
    "PromptScheduler",
    constructorParams,
    config,
    true
  )) as unknown as PromptScheduler;
  const workerHubAddress = workerHub.target;

  // DAO TOKEN UPDATE WORKER HUB ADDRESS
  console.log("DAO TOKEN UPDATE WORKER HUB ADDRESS...");
  const daoTokenContract = (await getContractInstance(
    daoTokenAddress,
    "DAOToken"
  )) as unknown as DAOToken;

  const tx = await daoTokenContract
    .connect(masterWallet)
    .updateWorkerHub(workerHubAddress);
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

  return workerHubAddress;
}

async function deployModelCollection() {
  console.log("DEPLOY MODEL COLLECTION...");

  const treasuryAddress = config.l2OwnerAddress;
  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = treasuryAddress;
  const royalPortion = 5_00;
  // const nextModelId = 140_001; // AVAX
  const nextModelId = 150_001; // BSC
  // const nextModelId = 160_001; // TRON

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
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

async function deployHybridModel(
  workerHubAddress: string,
  stakingHubAddress: string,
  collectionAddress: string
) {
  console.log("DEPLOY HYBRID MODEL...");
  // const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const StakingHub = await ethers.getContractFactory("StakingHub");
  const ModelCollection = await ethers.getContractFactory("ModelCollection");

  assert.ok(collectionAddress, `Missing ${networkName}_COLLECTION_ADDRESS !`);
  assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);
  const modelOwnerAddress = config.l2OwnerAddress;
  assert.ok(
    modelOwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const identifier = 0;
  const name = "ETERNAL V2";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "ETERNAL V2",
    model_type: "text",
    model_url: "",
    model_file_hash: "",
    min_hardware: 1,
    verifier_url: "",
    verifier_file_hash: "",
  };
  const metadata = JSON.stringify(metadataObj, null, "\t");

  const constructorParams = [
    workerHubAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];
  const hybridModel = (await deployOrUpgrade(
    undefined,
    "HybridModel",
    constructorParams,
    config,
    true
  )) as unknown as HybridModel;

  const hybridModelAddress = hybridModel.target;

  // COLLECTION MINT NFT TO MODEL OWNER
  const signer1 = (await ethers.getSigners())[0];
  console.log("COLLECTION MINT NFT TO MODEL OWNER...");
  const collection = ModelCollection.attach(
    collectionAddress
  ) as ModelCollection;
  const mintReceipt = await (
    await collection
      .connect(signer1)
      .mint(modelOwnerAddress, metadata, hybridModelAddress)
  ).wait();

  const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
    (event: EventLog) => event.eventName === "NewToken"
  );
  if (newTokenEvent) {
    console.log("tokenId: ", newTokenEvent.args?.tokenId);
  }

  // STAKING HUB REGISTER MODEL
  console.log("STAKING HUB REGISTER MODEL...");
  const stakingHub = StakingHub.attach(stakingHubAddress) as StakingHub;
  const txRegis = await stakingHub.registerModel(
    hybridModelAddress,
    minHardware,
    ethers.parseEther("0")
  );
  const receipt = await txRegis.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);

  return hybridModelAddress;
}

async function deploySystemPromptManager(
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
  const nextModelId = 1;

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

  const systemPromptManager = (await deployOrUpgrade(
    undefined,
    "SystemPromptManager",
    constructorParams,
    config,
    true
  )) as unknown as SystemPromptManager;

  return systemPromptManager.target;
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

  return squadManager.target;
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
  const masterWallet = (await ethers.getSigners())[0];

  const daoTokenAddress = await deployDAOToken();
  const treasuryAddress = await deployTreasury(daoTokenAddress.toString());
  const stakingHubAddress = await deployStakingHub(
    daoTokenAddress.toString(),
    treasuryAddress.toString()
  );
  const workerHubAddress = await deployWorkerHub(
    daoTokenAddress.toString(),
    treasuryAddress.toString(),
    stakingHubAddress.toString(),
    masterWallet
  );
  const collectionAddress = await deployModelCollection();

  const hybridModelAddress = await deployHybridModel(
    workerHubAddress.toString(),
    stakingHubAddress.toString(),
    collectionAddress.toString()
  );

  const systemPromptManagerAddress = await deploySystemPromptManager(
    config.l2OwnerAddress,
    hybridModelAddress.toString(),
    workerHubAddress.toString()
  );

  const squadManager = await deploySquadManager(
    systemPromptManagerAddress.toString()
  );

  const deployedAddresses = {
    daoTokenAddress,
    treasuryAddress,
    stakingHubAddress,
    workerHubAddress,
    collectionAddress,
    hybridModelAddress,
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

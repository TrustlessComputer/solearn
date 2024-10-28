import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  SystemPromptManager,
  Treasury,
  WorkerHub,
  WorkerHubScoring,
} from "../typechain-types";
import { deployOrUpgrade } from "./lib/utils";
import { EventLog, Signer } from "ethers";
import path from "path";
import fs from "fs";
import { combineDurations } from "./utils";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployDAOToken() {
  console.log("DEPLOY DAO TOKEN...");

  const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000"); //2,1B
  const tokenName = "FANS";
  const tokenSymbol = "FANS";
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

async function deployWorkerHub(
  daoTokenAddress: string,
  treasuryAddress: string,
  masterWallet: Signer
) {
  console.log("DEPLOY WORKER HUB...");

  const l2OwnerAddress = config.l2OwnerAddress;
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);
  assert.ok(treasuryAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);

  const feeL2Percentage = 0;
  const feeTreasuryPercentage = 100_00;
  const minerMinimumStake = ethers.parseEther("0.1");
  const minerRequirement = 3;
  const blockPerEpoch = 600 * 2;
  const rewardPerEpoch = ethers.parseEther("0.38");
  const submitDuration = 10 * 6 * 5;
  const commitDuration = 10 * 6 * 5;
  const revealDuration = 10 * 6 * 5;
  const unstakeDelayTime = 1814400; // NOTE:  1,814,400 blocks = 21 days
  const penaltyDuration = 0; // NOTE: 3.3 hours
  const finePercentage = 0;
  const feeRatioMinerValidator = 50_00; // Miner earns 50% of the workers fee ( = [msg.value - L2's owner fee - treasury] )
  const minFeeToUse = ethers.parseEther("0");
  const daoTokenReward = ethers.parseEther("0");
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

  const tx = await daoTokenContract
    .connect(masterWallet)
    .updateWorkerHub(workerHubAddress);
  const receipt = await tx.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);

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
  const nextModelId = 400_001; //

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
  collectionAddress: string
) {
  console.log("DEPLOY HYBRID MODEL...");
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const ModelCollection = await ethers.getContractFactory("ModelCollection");

  assert.ok(collectionAddress, `Missing ${networkName}_COLLECTION_ADDRESS !`);
  assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);
  const modelOwnerAddress = config.l2OwnerAddress;
  assert.ok(
    modelOwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const identifier = 0;
  const name = "FANS V2";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "FANS V2",
    model_type: "image",
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
    null,
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

  // WORKER HUB REGISTER MODEL
  console.log("WORKER HUB REGISTER MODEL...");
  const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
  const txRegis = await workerHub.registerModel(
    hybridModelAddress,
    minHardware,
    ethers.parseEther("0")
  );
  const receipt = await txRegis.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);

  return hybridModelAddress;
}

async function deployWorkerHubScoring(
  l2OwnerAddress: string,
  treasuryAddress: string,
  daoTokenAddress: string
) {
  console.log("DEPLOY WORKER HUB SCORING ...");

  assert.ok(l2OwnerAddress, `Missing ${networkName}_L2_OWNER_ADDRESS!`);
  assert.ok(treasuryAddress, `Missing ${networkName}_TREASURY_ADDRESS!`);
  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);

  const feeL2Percentage = 0;
  const feeTreasuryPercentage = 100_00;
  const minerMinimumStake = ethers.parseEther("0.1");
  const minerRequirement = 3;
  const blockPerEpoch = 600 * 2;
  const rewardPerEpoch = ethers.parseEther("0"); //ethers.parseEther("0.6659");
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
    null,
    "WorkerHubScoring",
    constructorParams,
    config,
    true
  )) as unknown as WorkerHubScoring;

  const workerHubScoringAddress = workerHubScoring.target;
  return workerHubScoringAddress;
}

async function deployHybridModelScoring(
  collectionAddress: string,
  workerHubScoringAddress: string,
  workerHubAddress: string,
  l2OwnerAddress: string
) {
  console.log("DEPLOY HYBRID MODEL SCORING ...");

  const WorkerHubScoring = await ethers.getContractFactory("WorkerHubScoring");
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const ModelCollection = await ethers.getContractFactory("ModelCollection");

  assert.ok(collectionAddress, `Missing ${networkName}_COLLECTION_ADDRESS!`);
  assert.ok(
    workerHubScoringAddress,
    `Missing ${networkName}_WORKER_HUB_SCORING_ADDRESS!`
  );
  assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);
  assert.ok(l2OwnerAddress, `Missing ${networkName}_L2_OWNER_ADDRESS!`);

  const identifier = 0;
  const name = "Scoring";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "Scoring",
    model_type: "scoring",
    model_url: "",
    model_file_hash: "",
    min_hardware: 1,
    verifier_url: "",
    verifier_file_hash: "",
  };
  const metadata = JSON.stringify(metadataObj, null, "\t");
  console.log(metadata);

  const constructorParams = [
    workerHubScoringAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];
  const hybridModel = (await deployOrUpgrade(
    null,
    "HybridModel",
    constructorParams,
    config,
    true
  )) as unknown as HybridModel;

  const collection = ModelCollection.attach(
    collectionAddress
  ) as ModelCollection;
  const mintReceipt = await (
    await collection.mint(l2OwnerAddress, metadata, hybridModel.target)
  ).wait();

  const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
    (event: EventLog) => event.eventName === "NewToken"
  );
  if (newTokenEvent) {
    console.log("tokenId:", newTokenEvent.args?.tokenId);
  }

  const workerHubScoring = WorkerHubScoring.attach(
    workerHubScoringAddress
  ) as WorkerHubScoring;
  const txRegis = await workerHubScoring.registerModel(
    hybridModel.target,
    minHardware,
    ethers.parseEther("0")
  );
  const receiptRegis = await txRegis.wait();
  console.log("TX hash: ", receiptRegis?.hash);
  console.log(
    `Contract HybridModelScoring is registered to WorkerHubScoring: ${receiptRegis?.status}`
  );

  // WorkerHubScoring setupScoringVar
  const txSetup = await workerHubScoring.setupScoringVar(workerHubAddress);
  const receiptSetup = await txSetup.wait();
  console.log("Tx hash: ", receiptSetup?.hash);
  console.log(
    `Contract WorkerHubScoring know WorkerHub: ${receiptSetup?.status}`
  );

  // WorkerHub setScoringInfo
  const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
  const txSetup2 = await workerHub.setScoringInfo(
    workerHubScoringAddress,
    hybridModel.target
  );
  const receiptSetup2 = await txSetup2.wait();
  console.log("Tx hash: ", receiptSetup2?.hash);
  console.log(
    `Contract WorkerHub setup Scoring Info: ${receiptSetup2?.status}`
  );

  return hybridModel.target;
}

async function deploySystemPromptManager(
  l2OwnerAddress: string,
  hybridModelAddress: string,
  workerHubAddress: string
) {
  console.log("DEPLOY SYSTEM PROMPT MANAGER...");

  assert.ok(l2OwnerAddress, `Missing ${networkName}_L2_OWNER_ADDRESS!`);

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
    undefined,
    "SystemPromptManager",
    constructorParams,
    config,
    true
  )) as unknown as SystemPromptManager;

  // Mint first NFT to owner

  return sysPromptManager.target;
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
  const workerHubAddress = await deployWorkerHub(
    daoTokenAddress.toString(),
    treasuryAddress.toString(),
    masterWallet
  );
  const collectionAddress = await deployModelCollection();
  const hybridModelAddress = await deployHybridModel(
    workerHubAddress.toString(),
    collectionAddress.toString()
  );
  const workerHubScoringAddress = await deployWorkerHubScoring(
    config.l2OwnerAddress,
    treasuryAddress.toString(),
    daoTokenAddress.toString()
  );
  const hybridModelScoringAddress = await deployHybridModelScoring(
    collectionAddress.toString(),
    workerHubScoringAddress.toString(),
    workerHubAddress.toString(),
    config.l2OwnerAddress
  );
  const systemPromptManagerAddress = await deploySystemPromptManager(
    config.l2OwnerAddress,
    hybridModelAddress.toString(),
    workerHubAddress.toString()
  );

  const deployedAddresses = {
    daoTokenAddress,
    treasuryAddress,
    workerHubAddress,
    collectionAddress,
    hybridModelAddress,
    workerHubScoringAddress,
    hybridModelScoringAddress,
    systemPromptManagerAddress,
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

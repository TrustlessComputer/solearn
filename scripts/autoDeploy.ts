import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  ProxyAdmin,
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
import { DAOToken } from "../typechain-types/contracts/tokens/DAOToken";
import { HybridModel } from "../typechain-types/contracts/HybridModel";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function getContractFactory(contractName: string) {
  return await ethers.getContractFactory(contractName);
}

async function deployProxyAdmin() {
  if (!config.proxyAdminAddress) {
    const factory = await ethers.getContractFactory("ProxyAdmin");
    const proxyAdmin = await factory.deploy();
    return proxyAdmin.target;
  }
  return config.proxyAdminAddress;
}

async function deployImpl(contractName: string) {
  const factory = await ethers.getContractFactory(contractName);
  const impl = await factory.deploy();
  console.log(`${contractName} deployed to: `, impl.target);
  return impl.target;
}

async function deployProxy(logic: string, admin: string, data: string) {
  const factory = await ethers.getContractFactory(
    "TransparentUpgradeableProxy"
  );

  const proxy = await factory.deploy(logic, admin, data);
  console.log("Proxy deployed to: ", proxy.target);
  return proxy.target;
}

async function upgrade(proxy: string, logic: string, admin: string) {
  console.log("proxy: ", proxy);
  console.log("logic: ", logic);
  console.log("admin: ", admin);
  const signer = (await ethers.getSigners())[0];
  const factory = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = factory.attach(admin) as ProxyAdmin;
  const tx = await proxyAdmin.connect(signer).upgrade(proxy, logic);
  const receipt = await tx.wait();
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status);
  // return tx;
}

async function deployDAOToken() {
  console.log("DEPLOY DAO TOKEN...");

  const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000"); //2,1B
  const tokenName = "DAOTOKEN";
  const tokenSymbol = "DAOTOKEN";
  const initializedParams = [tokenName, tokenSymbol, _MAX_SUPPLY_CAP];

  // deploy implementation
  // const impAddr = await deployImpl("DAOToken");
  const impAddr = "0x8377869e71e12F8a5c12115Cb745cAB7939D190f";

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(string,string,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x8E8019829aAAE4eC9260D8c46ab24B71D105bEAe";

  // Upgrade
  await upgrade(
    proxyAddr.toString(),
    impAddr.toString(),
    config.proxyAdminAddress
  );
}

async function deployWEAIToken() {
  console.log("DEPLOY WEAI TOKEN...");

  const initializedParams = [];

  // deploy implementation
  const impAddr = await deployImpl("WrappedEAI");
}

async function deployTreasury(daoTokenAddress: string) {
  console.log("DEPLOY TREASURY...");

  assert.ok(daoTokenAddress, `Missing ${networkName}_DAO_TOKEN_ADDRESS!`);
  const initializedParams = [daoTokenAddress];

  // deploy implementation
  // const impAddr = await deployImpl("Treasury");
  const impAddr = "0xfd592EAfea082F7626c0e2860b768d20BBd2EEb3";

  // deploy proxy
  // Encode the function call
  // const functionSignature = "initialize(address)";
  // const iface = new ethers.Interface([`function ${functionSignature}`]);
  // const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x47fb0318d560461E9473699d3830A9Bf2e5FdE8D";

  // Upgrade
  await upgrade(
    proxyAddr.toString(),
    impAddr.toString(),
    config.proxyAdminAddress
  );

  // return proxyAddr;
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

  const initializedParams = [
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
    [
      daoTokenPercentage.minerPercentage,
      daoTokenPercentage.userPercentage,
      daoTokenPercentage.referrerPercentage,
      daoTokenPercentage.refereePercentage,
      daoTokenPercentage.l2OwnerPercentage,
    ],
  ];

  // deploy implementation
  // const impAddr = await deployImpl("WorkerHub");
  const impAddr = "0x050dd45E11bDEb0a79135ba0e5f0471cBe74B5A1";

  // deploy proxy
  // Encode the function call
  // const functionSignature =
  //   "initialize(address,address,address,uint16,uint16,uint256,uint8,uint256,uint256,uint256,uint16,uint16,uint256,uint256,(uint16,uint16,uint16,uint16,uint16))";
  // const iface = new ethers.Interface([`function ${functionSignature}`]);
  // const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x620Bb2A3c52dc3DD4078D5D77d8694b411cd4Df8";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );
  const ins = (await getContractInstance(proxyAddr, "WorkerHub")) as WorkerHub;
  // const tx = await ins.setMinerMinimumStake(ethers.parseEther("25000"));
  // const res = await tx.wait();
  // console.log(`setMinerMinimumStake tx hash: ${res?.hash}`);
  // console.log(`setMinerMinimumStake status: ${res?.status}`);
  console.log("x ", await ins.minerMinimumStake());

  // const workerHubAddress = workerHub.target;

  // DAO TOKEN UPDATE WORKER HUB ADDRESS
  // console.log("DAO TOKEN UPDATE WORKER HUB ADDRESS...");
  // const daoTokenContract = (await getContractInstance(
  //   daoTokenAddress,
  //   "DAOToken"
  // )) as unknown as DAOToken;

  // const tx = await daoTokenContract
  //   .connect(masterWallet)
  //   .updateWorkerHub(workerHubAddress);
  // const receipt = await tx.wait();
  // console.log("Tx hash: ", receipt?.hash);
  // console.log("Tx status: ", receipt?.status);

  // return workerHubAddress;
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
  const nextModelId = 600_001; //

  const initializedParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
  ];

  // deploy implementation
  // const impAddr = await deployImpl("ModelCollection");
  const impAddr = "0xc35F8766BAE79cb3B7E277E6436fCC0b3bAda970";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(string,string,uint256,address,uint16,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x83bEA4E15b0633D980131A96C19a34a25D98262f";

  // Upgrade
  await upgrade(
    proxyAddr.toString(),
    impAddr.toString(),
    config.proxyAdminAddress
  );
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

  const initializedParams = [
    workerHubAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];

  // deploy implementation
  // const impAddr = await deployImpl("HybridModel");
  const impAddr = "0xA8023d8cbE685d3BEA81AE2BA53E2064901fE7Bb";

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(address,address,uint256,string,string)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0xA339801ec19B384246574C9863B5af224D9F85cf";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  const hybridModelAddress = proxyAddr;

  // COLLECTION MINT NFT TO MODEL OWNER
  // const signer1 = (await ethers.getSigners())[0];
  // console.log("COLLECTION MINT NFT TO MODEL OWNER...");
  // const collection = ModelCollection.attach(
  //   collectionAddress
  // ) as ModelCollection;
  // const mintReceipt = await (
  //   await collection
  //     .connect(signer1)
  //     .mint(modelOwnerAddress, metadata, hybridModelAddress)
  // ).wait();

  // const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
  //   (event: EventLog) => event.eventName === "NewToken"
  // );
  // if (newTokenEvent) {
  //   console.log("tokenId: ", newTokenEvent.args?.tokenId);
  // }

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

  // return hybridModelAddress;
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

  const initializedParams = [
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
    [
      daoTokenPercentage.minerPercentage,
      daoTokenPercentage.userPercentage,
      daoTokenPercentage.referrerPercentage,
      daoTokenPercentage.refereePercentage,
      daoTokenPercentage.l2OwnerPercentage,
    ],
  ];

  // deploy implementation
  // const impAddr = await deployImpl("WorkerHubScoring");
  const impAddr = "0xb2090eb064EDe2FD984CF9d9A00ac1D3bE810432";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(address,address,address,uint16,uint16,uint256,uint8,uint256,uint256,uint256,uint16,uint16,uint256,uint256,(uint16,uint16,uint16,uint16,uint16))";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x1B0515490f25517d7148a299F6532580792D331a";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  // return proxyAddr;
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

  const initializedParams = [
    workerHubScoringAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];

  // deploy implementation
  // const impAddr = await deployImpl("HybridModel");
  const impAddr = "0x3c60b06F7742269700a0d30a456A79155BB4151F";

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(address,address,uint256,string,string)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x79A41787eBbee99D05a6e22c24A095F91164383f";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  const hybridModelAddress = proxyAddr;

  // const collection = ModelCollection.attach(
  //   collectionAddress
  // ) as ModelCollection;
  // const mintReceipt = await (
  //   await collection.mint(l2OwnerAddress, metadata, hybridModelAddress)
  // ).wait();

  // const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
  //   (event: EventLog) => event.eventName === "NewToken"
  // );
  // if (newTokenEvent) {
  //   console.log("tokenId:", newTokenEvent.args?.tokenId);
  // }

  const workerHubScoring = WorkerHubScoring.attach(
    workerHubScoringAddress
  ) as WorkerHubScoring;
  // const txRegis = await workerHubScoring.registerModel(
  //   hybridModelAddress,
  //   minHardware,
  //   ethers.parseEther("0")
  // );
  // const receiptRegis = await txRegis.wait();
  // console.log("TX hash: ", receiptRegis?.hash);
  // console.log(
  //   `Contract HybridModelScoring is registered to WorkerHubScoring: ${receiptRegis?.status}`
  // );

  // WorkerHubScoring setupScoringVar
  // const txSetup = await workerHubScoring.setupScoringVar(workerHubAddress);
  // const receiptSetup = await txSetup.wait();
  // console.log("Tx hash: ", receiptSetup?.hash);
  // console.log(
  //   `Contract WorkerHubScoring know WorkerHub: ${receiptSetup?.status}`
  // );

  // WorkerHub setScoringInfo
  const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
  const txSetup2 = await workerHub.setScoringInfo(
    workerHubScoringAddress,
    hybridModelAddress
  );
  const receiptSetup2 = await txSetup2.wait();
  console.log("Tx hash: ", receiptSetup2?.hash);
  console.log(
    `Contract WorkerHub setup Scoring Info: ${receiptSetup2?.status}`
  );

  // return hybridModelAddress;
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

  const initializedParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    hybridModelAddress,
    workerHubAddress,
  ];

  // deploy implementation
  // const impAddr = await deployImpl("SystemPromptManager");
  const impAddr = "0x86091bBe7496fAEa559775B71d8F12Bc2206Dd3A";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(string,string,uint256,address,uint16,uint256,address,address)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x7734c3cd8B3239eA03A8A660095d94183FE63fCD";

  // Upgrade
  await upgrade(
    proxyAddr.toString(),
    impAddr.toString(),
    config.proxyAdminAddress
  );

  // Mint first NFT to owner
  // const nftOwner = (await ethers.getSigners())[0].address;
  // const ins = (await getContractInstance(
  //   proxyAddr,
  //   "SystemPromptManager"
  // )) as SystemPromptManager;

  // const metadataObj = {
  //   agent_uri: "ipfs://meta",
  // };
  // const metadata = JSON.stringify(metadataObj, null, "\t");
  // const linkPrompt = "ifps://systemprompt";
  // const uri = metadata;
  // const _data = ethers.toUtf8Bytes(linkPrompt);
  // const fee = ethers.parseEther("0");
  // const txMint = await ins.mint(nftOwner, uri, _data, fee);
  // const res = await txMint.wait();
  // console.log(`Minted tx hash: ${res?.hash}`);
  // console.log(`Minted status: ${res?.status}`);

  // return sysPromptManager.target;
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

  // ProxyAdmin
  const proxyAdminAddress = await deployProxyAdmin();
  console.log("ProxyAdmin deployed to: ", proxyAdminAddress);

  // DAO token deployment
  // await deployDAOToken();

  // Treasury deployment
  // await deployTreasury(config.daoTokenAddress);

  // const workerHubAddress = await deployWorkerHub(
  //   config.daoTokenAddress,
  //   config.treasuryAddress,
  //   masterWallet
  // );
  // const collectionAddress = await deployModelCollection();
  // await deployWEAIToken();
  // const hybridModelAddress = await deployHybridModel(
  //   config.workerHubAddress,
  //   config.collectionAddress
  // );
  // const workerHubScoringAddress = await deployWorkerHubScoring(
  //   config.l2OwnerAddress,
  //   config.treasuryAddress,
  //   config.daoTokenAddress
  // );
  // const hybridModelScoringAddress = await deployHybridModelScoring(
  //   config.collectionAddress,
  //   config.workerHubScoringAddress,
  //   config.workerHubAddress,
  //   config.l2OwnerAddress
  // );
  const systemPromptManagerAddress = await deploySystemPromptManager(
    config.l2OwnerAddress,
    config.hybridModelAddress,
    config.workerHubAddress
  );

  // const DAOToken = (await getContractInstance(
  //   config.daoTokenAddress,
  //   "DAOToken"
  // )) as DAOToken;
  // await DAOToken.updateWorkerHub(config.workerHubAddress);
  // console.log("DAOToken.workerHub ", await DAOToken.name());

  // const Treasury = (await getContractInstance(
  //   config.treasuryAddress,
  //   "Treasury"
  // )) as Treasury;
  // console.log("Treasury.owner ", await Treasury.owner());

  // const WorkerHub = (await getContractInstance(
  //   config.workerHubAddress,
  //   "WorkerHub"
  // )) as WorkerHub;
  // console.log("WorkerHub.owner ", await WorkerHub.owner());

  // const WorkerHubScoring = (await getContractInstance(
  //   config.workerHubScoringAddress,
  //   "WorkerHubScoring"
  // )) as WorkerHubScoring;
  // console.log("WorkerHubScoring.owner ", await WorkerHubScoring.owner());

  // const ModelCollection = (await getContractInstance(
  //   config.collectionAddress,
  //   "ModelCollection"
  // )) as ModelCollection;
  // console.log("ModelCollection.owner ", await ModelCollection.owner());

  // const HybridModel = (await getContractInstance(
  //   config.hybridModelAddress,
  //   "HybridModel"
  // )) as HybridModel;
  // console.log("HybridModel.owner ", await HybridModel.owner());

  // const HybridModelScoring = (await getContractInstance(
  //   config.hybridModelScoringAddress,
  //   "HybridModel"
  // )) as HybridModel;
  // console.log("HybridModelScoring.owner ", await HybridModelScoring.owner());

  // const SystemPromptManager = (await getContractInstance(
  //   config.systemPromptManagerAddress,
  //   "SystemPromptManager"
  // )) as SystemPromptManager;
  // console.log(
  //   "SystemPromptManager.tokenURI ",
  //   await SystemPromptManager.tokenURI(1n)
  // );

  const deployedAddresses = {
    proxyAdminAddress,
    // daoTokenAddress,
    // treasuryAddress,
    // workerHubAddress,
    // collectionAddress,
    // hybridModelAddress,
    // workerHubScoringAddress,
    // hybridModelScoringAddress,
    // systemPromptManagerAddress,
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

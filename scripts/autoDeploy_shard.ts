import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  DAOToken,
  HybridModel,
  IWorkerHub,
  ModelCollection,
  ProxyAdmin,
  StakingHub,
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
  const signer = (await ethers.getSigners())[0];
  const currentNonce = await signer.getNonce();
  console.log(`Deploying with nonce: ${currentNonce}`);

  // console.log("balance: ", await ethers.provider.getBalance(signer.address));

  const factory = await ethers.getContractFactory(
    "TransparentUpgradeableProxy"
  );

  const proxy = await factory.deploy(logic, admin, data);
  console.log("Proxy deployed to: ", proxy.target);
  return proxy.target;
}

async function deployProxy2(logic: string, admin: string, data: string) {
  const signer = (await ethers.getSigners())[0];
  const currentNonce = await signer.getNonce();

  const factory = await ethers.getContractFactory(
    "TransparentUpgradeableProxy"
  );
  const x = await factory.getDeployTransaction(logic, admin, data);
  const customNonce: number = 8;
  console.log(`Deploying with nonce: ${customNonce}`);

  const tx = {
    data: x.data,
    nonce: customNonce ?? (await signer.getNonce()),
  };

  const deployTx = await signer.sendTransaction(tx);
  const receipt = await deployTx.wait();

  console.log(`Deployed to: ${receipt?.contractAddress}`);
  console.log(`Used nonce: ${tx.nonce}`);

  return receipt?.contractAddress;
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
  // const impAddr = "0x8377869e71e12F8a5c12115Cb745cAB7939D190f"; #shard
  const impAddr = "0xc3A7148E6DDA09d0f077F8eCAf3eb4F6586D3B72"; // bittensor

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(string,string,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);
  const proxyAdminAddress = "0xe59647F07F8e250BAc45b767ef0Cb4f947242d0e";

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   proxyAdminAddress,
  //   data
  // );
  // const proxyAddr = "0x8E8019829aAAE4eC9260D8c46ab24B71D105bEAe"; //shard
  const proxyAddr = "0x8d6F08c068EAfd8A2Bc642452dE7A1a4dc40C023"; //bittensor

  // Upgrade
  await upgrade(proxyAddr.toString(), impAddr.toString(), proxyAdminAddress);
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
  // const impAddr = "0xfd592EAfea082F7626c0e2860b768d20BBd2EEb3"; //shard
  const impAddr = "0xFEe261Bc0ED05D44DfBe930edFbf58D73c9C0c43"; //bittensor

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(address)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", initializedParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  // const proxyAddr = "0x47fb0318d560461E9473699d3830A9Bf2e5FdE8D"; //shard
  const proxyAddr = "0xa747bDD8621416AC0A76634abaAfe5190bCff808"; //bittensor

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  // return proxyAddr;
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

  const unstakeDelayTime = 151200; // NOTE:  151200 blocks = 21 days (blocktime = 12)
  // const unstakeDelayTime = 907200; // NOTE:  907200 blocks = 21 days (blocktime = 2s) // Avax
  // const unstakeDelayTime = 604800; // NOTE:  604800 blocks = 21 days (blocktime = 3s) // BSC
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

  // deploy implementation
  // const impAddr = await deployImpl("StakingHub");
  const impAddr = "0x88b28bFb179cbe476645D22B9B1B44173CF83bd3";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(address,uint256,uint256,uint256,uint40,uint40,uint16,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", constructorParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x70bf394A2bfCD3AA49F2921A12C75B998b495CC1";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );
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
    [
      daoTokenPercentage.minerPercentage,
      daoTokenPercentage.userPercentage,
      daoTokenPercentage.referrerPercentage,
      daoTokenPercentage.refereePercentage,
      daoTokenPercentage.l2OwnerPercentage,
    ],
  ];

  // deploy implementation
  // const impAddr = await deployImpl("PromptScheduler");
  const impAddr = "0x809e66FA061120e2F4fC8f83bBffaB3e70A2Cce8";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(address,address,address,address,address,uint16,uint16,uint8,uint40,uint16,uint256,(uint16,uint16,uint16,uint16,uint16))";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", constructorParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x0A77958AB03E60a7e939f660D4cdC8862Ae0e966";

  // Upgrade;
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  const workerHubAddress = proxyAddr;

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

  // Staking Hub update WorkerHub Address
  // console.log("STAKING HUB UPDATE WORKER HUB ADDRESS...");
  // const stakingHubContract = (await getContractInstance(
  //   stakingHubAddress,
  //   "StakingHub"
  // )) as unknown as StakingHub;

  // const txUpdate = await stakingHubContract.setWorkerHubAddress(
  //   workerHubAddress
  // );
  // const receiptUpdate = await txUpdate.wait();
  // console.log("Tx hash: ", receiptUpdate?.hash);
  // console.log("Tx status: ", receiptUpdate?.status);

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
  // const nextModelId = 140_001; // AVAX
  // const nextModelId = 150_001; // BSC
  // const nextModelId = 160_001; // TRON
  const nextModelId = 180_001; // Biittensor

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
  ];

  // deploy implementation
  // const impAddr = await deployImpl("ModelCollection");
  const impAddr = "0x9E78Dd04eFAF8222BAaddbBe987088f50A8Bfbe5";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(string,string,uint256,address,uint16,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", constructorParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0x15e92aB726473773C2afedadc6ACDb2f8f449E58";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );
}

// async function deployModelCollection() {
//   console.log("DEPLOY MODEL COLLECTION...");

//   const treasuryAddress = config.l2OwnerAddress;
//   assert.ok(
//     treasuryAddress,
//     `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
//   );

//   const name = "Eternal AI";
//   const symbol = "";
//   const mintPrice = ethers.parseEther("0");
//   const royaltyReceiver = treasuryAddress;
//   const royalPortion = 5_00;
//   const nextModelId = 600_001; //

//   const initializedParams = [
//     name,
//     symbol,
//     mintPrice,
//     royaltyReceiver,
//     royalPortion,
//     nextModelId,
//   ];

//   // deploy implementation
//   // const impAddr = await deployImpl("ModelCollection");
//   const impAddr = "0xc35F8766BAE79cb3B7E277E6436fCC0b3bAda970";

//   // deploy proxy
//   // Encode the function call
//   const functionSignature =
//     "initialize(string,string,uint256,address,uint16,uint256)";
//   const iface = new ethers.Interface([`function ${functionSignature}`]);
//   const data = iface.encodeFunctionData("initialize", initializedParams);

//   // const proxyAddr = await deployProxy(
//   //   impAddr.toString(),
//   //   config.proxyAdminAddress,
//   //   data
//   // );
//   const proxyAddr = "0x83bEA4E15b0633D980131A96C19a34a25D98262f";

//   // Upgrade
//   await upgrade(
//     proxyAddr.toString(),
//     impAddr.toString(),
//     config.proxyAdminAddress
//   );
// }

// async function deployHybridModel(
//   workerHubAddress: string,
//   collectionAddress: string
// ) {
//   console.log("DEPLOY HYBRID MODEL...");
//   const WorkerHub = await ethers.getContractFactory("WorkerHub");
//   const ModelCollection = await ethers.getContractFactory("ModelCollection");

//   assert.ok(collectionAddress, `Missing ${networkName}_COLLECTION_ADDRESS !`);
//   assert.ok(workerHubAddress, `Missing ${networkName}_WORKER_HUB_ADDRESS!`);
//   const modelOwnerAddress = config.l2OwnerAddress;
//   assert.ok(
//     modelOwnerAddress,
//     `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
//   );

//   const identifier = 0;
//   const name = "FANS V2";
//   const minHardware = 1;
//   const metadataObj = {
//     version: 1,
//     model_name: "FANS V2",
//     model_type: "image",
//     model_url: "",
//     model_file_hash: "",
//     min_hardware: 1,
//     verifier_url: "",
//     verifier_file_hash: "",
//   };
//   const metadata = JSON.stringify(metadataObj, null, "\t");

//   const initializedParams = [
//     workerHubAddress,
//     collectionAddress,
//     identifier,
//     name,
//     metadata,
//   ];

//   // deploy implementation
//   // const impAddr = await deployImpl("HybridModel");
//   const impAddr = "0xA8023d8cbE685d3BEA81AE2BA53E2064901fE7Bb";

//   // deploy proxy
//   // Encode the function call
//   const functionSignature = "initialize(address,address,uint256,string,string)";
//   const iface = new ethers.Interface([`function ${functionSignature}`]);
//   const data = iface.encodeFunctionData("initialize", initializedParams);

//   // const proxyAddr = await deployProxy(
//   //   impAddr.toString(),
//   //   config.proxyAdminAddress,
//   //   data
//   // );
//   const proxyAddr = "0xA339801ec19B384246574C9863B5af224D9F85cf";

//   // Upgrade
//   // await upgrade(
//   //   proxyAddr.toString(),
//   //   impAddr.toString(),
//   //   config.proxyAdminAddress
//   // );

//   const hybridModelAddress = proxyAddr;

//   // COLLECTION MINT NFT TO MODEL OWNER
//   // const signer1 = (await ethers.getSigners())[0];
//   // console.log("COLLECTION MINT NFT TO MODEL OWNER...");
//   // const collection = ModelCollection.attach(
//   //   collectionAddress
//   // ) as ModelCollection;
//   // const mintReceipt = await (
//   //   await collection
//   //     .connect(signer1)
//   //     .mint(modelOwnerAddress, metadata, hybridModelAddress)
//   // ).wait();

//   // const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
//   //   (event: EventLog) => event.eventName === "NewToken"
//   // );
//   // if (newTokenEvent) {
//   //   console.log("tokenId: ", newTokenEvent.args?.tokenId);
//   // }

//   // WORKER HUB REGISTER MODEL
//   console.log("WORKER HUB REGISTER MODEL...");
//   const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
//   const txRegis = await workerHub.registerModel(
//     hybridModelAddress,
//     minHardware,
//     ethers.parseEther("0")
//   );
//   const receipt = await txRegis.wait();
//   console.log("Tx hash: ", receipt?.hash);
//   console.log("Tx status: ", receipt?.status);

//   // return hybridModelAddress;
// }

async function deployHybridModel(
  workerHubAddress: string,
  stakingHubAddress: string,
  collectionAddress: string
) {
  console.log("DEPLOY HYBRID MODEL...");
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

  // deploy implementation
  // const impAddr = await deployImpl("HybridModel");
  const impAddr = "0x0f520ea04b1d7D228D5486e3cfC3F64cF7575EDE";

  // deploy proxy
  // Encode the function call
  const functionSignature = "initialize(address,address,uint256,string,string)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", constructorParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );
  const proxyAddr = "0xC47E14AC0ea793e25e9644b555cb5902423F78E7";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );

  const hybridModelAddress = proxyAddr;

  // COLLECTION MINT NFT TO MODEL OWNER
  const signer1 = (await ethers.getSigners())[0];
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

  // STAKING HUB REGISTER MODEL
  // console.log("STAKING HUB REGISTER MODEL...");
  // const stakingHub = StakingHub.attach(stakingHubAddress) as StakingHub;
  // const txRegis = await stakingHub.registerModel(
  //   hybridModelAddress,
  //   minHardware,
  //   ethers.parseEther("0")
  // );
  // const receipt = await txRegis.wait();
  // console.log("Tx hash: ", receipt?.hash);
  // console.log("Tx status: ", receipt?.status);

  // return hybridModelAddress;
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

  // deploy implementation
  // const impAddr = await deployImpl("SystemPromptManager");
  const impAddr = "0xd84f6785C38dA3ea4BEFBe07eD02C06DEd6945F6";

  // deploy proxy
  // Encode the function call
  const functionSignature =
    "initialize(string,string,uint256,address,uint16,uint256,address,address)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const data = iface.encodeFunctionData("initialize", constructorParams);

  // const proxyAddr = await deployProxy(
  //   impAddr.toString(),
  //   config.proxyAdminAddress,
  //   data
  // );

  const proxyAddr = "0x88feb137Ab8f971df6b8C098A2C05A22d8F480e7";

  // Upgrade
  // await upgrade(
  //   proxyAddr.toString(),
  //   impAddr.toString(),
  //   config.proxyAdminAddress
  // );
}

// async function deploySystemPromptManager(
//   l2OwnerAddress: string,
//   hybridModelAddress: string,
//   workerHubAddress: string
// ) {
//   console.log("DEPLOY SYSTEM PROMPT MANAGER...");

//   assert.ok(l2OwnerAddress, `Missing ${networkName}_L2_OWNER_ADDRESS!`);

//   const name = "Eternal AI";
//   const symbol = "";
//   const mintPrice = ethers.parseEther("0");
//   const royaltyReceiver = l2OwnerAddress;
//   const royalPortion = 5_00;
//   const nextModelId = 1; //TODO: need to change before deployment

//   const initializedParams = [
//     name,
//     symbol,
//     mintPrice,
//     royaltyReceiver,
//     royalPortion,
//     nextModelId,
//     hybridModelAddress,
//     workerHubAddress,
//   ];

//   // deploy implementation
//   // const impAddr = await deployImpl("SystemPromptManager");
//   const impAddr = "0x169c8Ee03422268E2D05F40059B9fA9fa97284a5";

//   // deploy proxy
//   // Encode the function call
//   const functionSignature =
//     "initialize(string,string,uint256,address,uint16,uint256,address,address)";
//   const iface = new ethers.Interface([`function ${functionSignature}`]);
//   const data = iface.encodeFunctionData("initialize", initializedParams);

//   // const proxyAddr = await deployProxy(
//   //   impAddr.toString(),
//   //   config.proxyAdminAddress,
//   //   data
//   // );
//   const proxyAddr = "0x7734c3cd8B3239eA03A8A660095d94183FE63fCD";

//   // Upgrade
//   // await upgrade(
//   //   proxyAddr.toString(),
//   //   impAddr.toString(),
//   //   config.proxyAdminAddress
//   // );

//   // Mint first NFT to owner
//   const nftOwner = (await ethers.getSigners())[0].address;
//   const ins = (await getContractInstance(
//     proxyAddr,
//     "SystemPromptManager"
//   )) as SystemPromptManager;

//   const metadataObj = {
//     agent_uri: "ipfs://meta",
//   };
//   const metadata = JSON.stringify(metadataObj, null, "\t");
//   const linkPrompt = "ifps://systemprompt";
//   const uri = metadata;
//   const _data = ethers.toUtf8Bytes(linkPrompt);
//   const fee = ethers.parseEther("0");
//   const txMint = await ins.mint(nftOwner, uri, _data, fee);
//   const res = await txMint.wait();
//   console.log(`Minted tx hash: ${res?.hash}`);
//   console.log(`Minted status: ${res?.status}`);

//   // return sysPromptManager.target;
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
  // const proxyAdminAddress = await deployProxyAdmin();
  // console.log("ProxyAdmin deployed to: ", proxyAdminAddress);
  const proxyAdminAddress = "0xe59647F07F8e250BAc45b767ef0Cb4f947242d0e";

  // DAO token deployment
  // await deployDAOToken();

  // Treasury deployment
  // await deployTreasury(config.daoTokenAddress);

  // Staking Hub deployment
  // await deployStakingHub(config.daoTokenAddress, config.treasuryAddress);

  // Worker Hub deployment
  // await deployWorkerHub(
  //   config.daoTokenAddress,
  //   config.treasuryAddress,
  //   config.stakingHubAddress,
  //   masterWallet
  // );

  // Model Collection deployment
  // await deployModelCollection();

  // Hybrid Model deployment
  // await deployHybridModel(
  //   config.workerHubAddress,
  //   config.stakingHubAddress,
  //   config.collectionAddress
  // );

  // System Prompt Manager deployment
  await deploySystemPromptManager(
    config.l2OwnerAddress,
    config.hybridModelAddress,
    config.workerHubAddress
  );

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
  // const systemPromptManagerAddress = await deploySystemPromptManager(
  //   config.l2OwnerAddress,
  //   config.hybridModelAddress,
  //   config.workerHubAddress
  // );

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

  // const deployedAddresses = {
  //   proxyAdminAddress,
  //   // daoTokenAddress,
  //   // treasuryAddress,
  //   // workerHubAddress,
  //   // collectionAddress,
  //   // hybridModelAddress,
  //   // workerHubScoringAddress,
  //   // hybridModelScoringAddress,
  //   // systemPromptManagerAddress,
  // };

  // const networkName = network.name.toUpperCase();

  // await saveDeployedAddresses(networkName, deployedAddresses);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  AgentUpgradeable,
  DAOToken,
  HybridModel,
  IAgent,
  IWorkerHub,
  ModelCollection,
  PromptScheduler,
  SquadManager,
  StakingHub,
  SystemPromptManager,
  Treasury,
  IBASERegistrarController, 
  IRegsitryENS,
  IResolverENS,
  IRegsitry,
} from "../typechain-types";
import { deployOrUpgrade } from "./lib/utils";
import { EventLog, Signer } from "ethers";
import path from "path";
import fs from "fs";
import * as hre from "hardhat";
import { getInitializerData } from "@openzeppelin/hardhat-upgrades/dist/utils/initializer-data";

const config = network.config as any;
const networkName = network.name.toUpperCase();

async function deployDAOToken() {
  console.log("DEPLOY DAO TOKEN...");

  // TODO: @mr 6789 check it
  // ***************************
  const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000"); //2,1B
  const tokenName = "DAOTOKEN";
  const tokenSymbol = "DAOTOKEN";
  // ***************************

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

  // TODO: @mr 6789 check it
  // ***************************
  const minerMinimumStake = ethers.parseEther("25000");
  const blockPerEpoch = (600 * 2) / 6;
  const rewardPerEpoch = ethers.parseEther("0.38");
  const unstakeDelayTime = 302400; // NOTE:  907200 blocks = 21 days (blocktime = 2s) // Avax
  const penaltyDuration = 0;
  const finePercentage = 0;
  const minFeeToUse = ethers.parseEther("0");
  // ***************************

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

  // TODO: @mr 6789 check it
  // ***************************
  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = treasuryAddress;
  const royalPortion = 5_00;
  // const nextModelId = 140_001; // AVAX
  // const nextModelId = 220_001; // MODE
  // const nextModelId = 160_001; // TRON
  // const nextModelId = 230_001; // CELO
  const nextModelId = 240_001; // ZETA

  // ***************************

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
    model_name: "unslot-DeepSeek-R1-Distill-Llama-70B-Q8_0",
    model_type: "text",
    model_url:
      "https://gateway.lighthouse.storage/ipfs/bafkreidpoxthbkrgq2zpcqhrujp2kdxqb7yysxfq5oy57inwmj4gjsv7si",
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

async function deployAgent() {
  console.log("DEPLOY AGENT...");
  const admin = (await ethers.getSigners())[0];

  const agentCfs: IAgent.CodePointerStruct[] = [
    {
      retrieveAddress: "0xFe1411d6864592549AdE050215482e4385dFa0FB",
      fileType: 0,
      fileName: "ethers.text",
    },
    {
      retrieveAddress: "0xFe1411d6864592549AdE050215482e4385dFa0FB",
      fileType: 1,
      fileName: "devScript.text",
    },
  ];

  const agentName = "TestAgent10";
  const agentVersion = "1";
  const agentLanguage = "javascript";
  const deps: string[] = [];
  const owner = admin.address;

  // ens base testnet
  const registrar = "0xBC89775F8A6Aa2ec81EB1e1149aaF398Ceb11aC6";
  const resolver = "0x6ceF0b500BCE501b9c71A1E160B1930cbEbbD157";
  const duration = 365 * 24 * 60 * 60; // 1 year

  const functionSignature = "initialize(address,address,uint256)";
  const iface = new ethers.Interface([`function ${functionSignature}`]);
  const nameService = "0x" + iface.encodeFunctionData("initialize", [registrar, resolver, duration]).slice(10);

  const ins = (await getContractInstance(
    registrar,
    "IBASERegistrarController"
  )) as unknown as IBASERegistrarController;

  const price = await ins.registerPrice(agentName, duration);
  console.log("price: ", price);

  const initParams = [
    agentName,
    agentVersion,
    agentLanguage,
    agentCfs,
    deps,
    owner,
    nameService,
  ];

  const agentUpgrade = await hre.ethers.getContractFactory("AgentUpgradeable");
  const implAddr = await upgrades.deployImplementation(agentUpgrade);
  const contractInterface = agentUpgrade.interface;
  const data = getInitializerData(contractInterface, initParams, "initialize");
  const transparentUpgrade = await hre.ethers.getContractFactory("TransparentUpgradeableProxy");
  // todo: update admin address
  const proxy = await transparentUpgrade.deploy(implAddr, "0xc15acdE807cf9fa5907A3fcDd3F79FE59BAea1b1", data, {value: price.toString()});

  // name => address
  console.log("resolve address: ", await resolveAddress(agentName + ".basetest.eth"));

  return await proxy.getAddress();
}

async function resolveAddress(inputName: string) {
  // address => name 
  const node = await nameHash(inputName);
  const insRegistry = (await getContractInstance(
    "0x616655C1F5D9DC6f5161Dd1656EE953f1C8dB995",
    "IRegsitryENS"
  )) as unknown as IRegsitryENS;

  const resolverAddr = await insRegistry.resolver(node);

  const insResolver = (await getContractInstance(
    resolverAddr,
    "IResolverENS"
  )) as unknown as IResolverENS;

  const address = await insResolver.addr(node);

  return address;
}

async function normalize(input: string): Promise<string> {
  try {
    // Convert to unicode normalized form (NFD)
    let output = input.normalize('NFD');
    
    // Preserve leading period if present in input
    if (input.startsWith('.') && !output.startsWith('.')) {
      output = '.' + output;
    }

    return output;
  } catch (err) {
    throw new Error(`Failed to convert to standard unicode: ${err}`);
  }
}

async function nameHash(name: string): Promise<string> {
  let hash = new Uint8Array(32); // Initialize 32-byte array with zeros

  if (name === '') {
    return ethers.hexlify(hash);
  }

  const normalizedName = await normalize(name);
  const labels = normalizedName.split('.');

  for (let i = labels.length - 1; i >= 0; i--) {
    try {
      const labelHash = ethers.keccak256(ethers.toUtf8Bytes(labels[i]));
      const concatRes = ethers.concat([hash, labelHash]);
      hash = ethers.keccak256(concatRes);
    } catch (err) {
      throw new Error(`Failed to hash label ${labels[i]}: ${err}`);
    }
  }

  return hash;
}

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  return await ethers.getContractAt(contractName, proxyAddress);
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

  // const wEAIAddress = config.wEAIAddress;
  // const daoTokenAddress = await deployDAOToken();
  // const treasuryAddress = await deployTreasury(daoTokenAddress.toString());
  // const stakingHubAddress = await deployStakingHub(
  //   daoTokenAddress.toString(),
  //   treasuryAddress.toString()
  // );
  // const workerHubAddress = await deployWorkerHub(
  //   daoTokenAddress.toString(),
  //   treasuryAddress.toString(),
  //   stakingHubAddress.toString(),
  //   masterWallet
  // );
  // const collectionAddress = await deployModelCollection();

  // const hybridModelAddress = await deployHybridModel(
  //   workerHubAddress.toString(),
  //   stakingHubAddress.toString(),
  //   collectionAddress.toString()
  // );

  // const systemPromptManagerAddress = await deploySystemPromptManager(
  //   config.l2OwnerAddress,
  //   hybridModelAddress.toString(),
  //   workerHubAddress.toString()
  // );

  // const deployedAddresses = {
  //   wEAIAddress,
  //   daoTokenAddress,
  //   treasuryAddress,
  //   stakingHubAddress,
  //   workerHubAddress,
  //   collectionAddress,
  //   hybridModelAddress,
  //   systemPromptManagerAddress,
  // };

  // const networkName = network.name.toUpperCase();

  // await saveDeployedAddresses(networkName, deployedAddresses);

  const agentAddr = await deployAgent();

  const ins = (await getContractInstance(
    agentAddr.toString(),
    "AgentUpgradeable"
  )) as unknown as AgentUpgradeable;

  console.log("Agent address: ", ins.target);
  console.log("Agent builtWith: ", await ins.getCodeLanguage());
  console.log("Agent version: ", await ins.getCurrentVersion());
  console.log("Agent name: ", await ins.getAgentName());
  console.log("Agent owner: ", await ins.getAgentOwner());

  // console.log(await ethers.provider.resolveName("kelvin26.eth"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import { ethers, upgrades, network, Signer } from "hardhat";
import { expect } from "chai";
import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers");

import { address18 } from "./address.seed.ts";

import {
  IWorkerHub,
  LLAMA,
  WorkerHub,
  ModelCollection,
  DAOToken,
  WrappedEAI,
  SystemPromptManager,
} from "../typechain-types/index.js";
import { AbiCoder, BytesLike, EventLog, wordlists } from "ethers";
import { HybridModel } from "../typechain-types/contracts/HybridModel.js";
import { StakingHub } from "../typechain-types/contracts/StakingHub";

describe("WorkerHub contract", async () => {
  const { provider } = ethers;
  async function deployWorkerHubFixture() {
    const [admin] = await ethers.getSigners();
    console.log(`admin: ${admin.address}`);

    const wEAIAddress = await deployWEAI();

    const proxyLLAMAAddress = await deployDAOToken();
    const modelCollectionAddress = await deployModelCollection();
    const stakingHubAddress = await deployStakingHub(
      proxyLLAMAAddress,
      wEAIAddress
    );
    const proxyWorkerHubAddress = await deployWorkerHub(
      proxyLLAMAAddress,
      stakingHubAddress,
      wEAIAddress
    );
    const hybridModelAddress = await deployHybridModel(
      proxyWorkerHubAddress,
      stakingHubAddress,
      modelCollectionAddress
    );

    const systemPromptManagerAddress = await deploySystemPromptManager(
      proxyWorkerHubAddress,
      hybridModelAddress,
      admin.address
    );

    return {
      admin,
      proxyLLAMAAddress,
      proxyWorkerHubAddress,
      stakingHubAddress,
      hybridModelAddress,
      wEAIAddress,
      systemPromptManagerAddress,
    };
  }

  async function deployModelCollection() {
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";

    const name = "Eternal AI";
    const symbol = "";
    const mintPrice = ethers.parseEther("0");
    const royaltyReceiver = treasuryAddress;
    const royalPortion = 5_00;
    const nextModelId = 300_001; //TODO: need to change before deployment

    const constructorParams = [
      name,
      symbol,
      mintPrice,
      royaltyReceiver,
      royalPortion,
      nextModelId,
    ];

    const contractFact = await ethers.getContractFactory("ModelCollection");

    const proxy = await upgrades.deployProxy(contractFact, constructorParams);
    await proxy.waitForDeployment();
    return await proxy.getAddress();
  }

  async function deployDAOToken() {
    const LLAMAFact = await ethers.getContractFactory("DAOToken");
    // const address0 = ethers.ZeroAddress;
    const name = "LLAMA";
    const symbol = "LLAMA";
    const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000");

    const proxyLLAMA = await upgrades.deployProxy(LLAMAFact, [
      name,
      symbol,
      _MAX_SUPPLY_CAP,
    ]);
    await proxyLLAMA.waitForDeployment();
    const proxyLLAMAAddress = await proxyLLAMA.getAddress();

    return proxyLLAMAAddress;
  }

  async function deployWEAI() {
    const WEAIFact = await ethers.getContractFactory("WrappedEAI");
    const wEAI = await WEAIFact.deploy();
    await wEAI.waitForDeployment();

    const wEAIAddress = await wEAI.getAddress();

    return wEAIAddress;
  }

  async function deployStakingHub(
    daoTokenAddress: string,
    wEAIAddress: string
  ) {
    const l2OwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";

    const minerMinimumStake = ethers.parseEther("0.1");
    const blockPerEpoch = 600;
    const rewardPerEpoch = ethers.parseEther("0");
    const unstakeDelayTime = 10 * 60;
    const penaltyDuration = 3600;
    const finePercentage = 5_00;
    const _minFeeToUse = ethers.parseEther("0.1");

    const constructorParams = [
      wEAIAddress,
      minerMinimumStake,
      blockPerEpoch,
      rewardPerEpoch,
      unstakeDelayTime,
      penaltyDuration,
      finePercentage,
      _minFeeToUse,
    ];

    const StakingHubFact = await ethers.getContractFactory("StakingHub");

    const proxyStakingHub = await upgrades.deployProxy(
      StakingHubFact,
      constructorParams
    );
    await proxyStakingHub.waitForDeployment();
    const proxyStakingHubAddress = await proxyStakingHub.getAddress();
    return proxyStakingHubAddress;
  }

  async function deployWorkerHub(
    daoTokenAddress: string,
    stakingHubAddress: string,
    wEAIAddress: string
  ) {
    const l2OwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";

    const feeL2Percentage = 10_00;
    const feeTreasuryPercentage = 10_00;
    const minerRequirement = 3;
    const submitDuration = 10 * 60;
    const commitDuration = 10 * 60;
    const revealDuration = 10 * 60;
    const feeRatioMinerValidator = 10_00;
    const _daoTokenReward = ethers.parseEther("0.1");
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
      commitDuration,
      revealDuration,
      feeRatioMinerValidator,
      _daoTokenReward,
      daoTokenPercentage,
    ];

    const WorkerHubFact = await ethers.getContractFactory("WorkerHub");

    const proxyWorkerHub = await upgrades.deployProxy(
      WorkerHubFact,
      constructorParams
    );
    await proxyWorkerHub.waitForDeployment();
    const proxyWorkerHubAddress = await proxyWorkerHub.getAddress();

    //*************************************************************** */
    const contractFact = await ethers.getContractFactory("DAOToken");
    const LLAMAIns = contractFact.attach(daoTokenAddress) as DAOToken;
    await LLAMAIns.updateWorkerHub(proxyWorkerHubAddress);

    //*************************************************************** */
    const StakingHubFact = await ethers.getContractFactory("StakingHub");
    const stakingHub = StakingHubFact.attach(stakingHubAddress) as StakingHub;
    await stakingHub.setWorkerHubAddress(proxyWorkerHubAddress);

    return proxyWorkerHubAddress;
  }

  async function deployHybridModel(
    workerHubAddress: string,
    stakingHubAddress: string,
    collectionAddress: string
  ) {
    const identifier = 0;
    const name = "Flux V2";
    const minHardware = 1;
    const metadataObj = {
      version: 1,
      model_name: "Flux V2",
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

    const contractFact = await ethers.getContractFactory("HybridModel");

    const proxy = await upgrades.deployProxy(contractFact, constructorParams);
    await proxy.waitForDeployment();
    const proxyAddress = await proxy.getAddress();

    //
    const WorkerHub = await ethers.getContractFactory("WorkerHub");
    const StakingHub = await ethers.getContractFactory("StakingHub");
    const ModelCollection = await ethers.getContractFactory("ModelCollection");
    const modelOwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";

    const collection = ModelCollection.attach(
      collectionAddress
    ) as ModelCollection;
    const mintReceipt = await (
      await collection.mint(modelOwnerAddress, metadata, proxyAddress)
    ).wait();

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
      (event: EventLog) => event.eventName === "NewToken"
    );
    if (newTokenEvent) {
      console.log("tokenId:", newTokenEvent.args?.tokenId);
    }

    const stakingHub = StakingHub.attach(stakingHubAddress) as StakingHub;
    await stakingHub.registerModel(
      proxyAddress,
      minHardware,
      ethers.parseEther("0.1")
    );

    return proxyAddress;
  }

  async function deploySystemPromptManager(
    workerHubAddress: string,
    hybridModelAddress: string,
    l2OwnerAddress: string
  ) {
    const name = "Eternal AI";
    const symbol = "1.0";
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

    const contractFact = await ethers.getContractFactory("SystemPromptManager");

    const proxy = await upgrades.deployProxy(contractFact, constructorParams);
    await proxy.waitForDeployment();
    const proxyAddress = await proxy.getAddress();

    //
    const ins = (await getContractInstance(
      "SystemPromptManager",
      proxyAddress
    )) as SystemPromptManager;
    const linkPrompt =
      "ipfs://bafkreide4kf4se2atgdi3kjie5eigvvr3wnkyolitbrj6cuj3sfzfyowui";

    const nftOwner = (await ethers.getSigners())[0].address;
    const uri = linkPrompt;
    const data = ethers.toUtf8Bytes(linkPrompt);
    const fee = ethers.parseEther("0");
    const txMint = await ins.mint(nftOwner, uri, data, fee);
    await ins.mint(nftOwner, uri, data, fee);

    return proxyAddress;
  }

  async function getContractInstance(contractName: string, address: string) {
    const contractFact = await ethers.getContractFactory(contractName);
    return contractFact.attach(address);
  }

  async function simulate(
    workerHubAddress: string,
    stakingHubAddress: string,
    hybridModelAddress: string,
    wEAIAddress: string
  ) {
    const workerHub = (await getContractInstance(
      "WorkerHub",
      workerHubAddress
    )) as WorkerHub;
    const stakingHub = (await getContractInstance(
      "StakingHub",
      stakingHubAddress
    )) as StakingHub;
    const wEAI = (await getContractInstance(
      "WrappedEAI",
      wEAIAddress
    )) as WrappedEAI;

    const [admin] = await ethers.getSigners();

    //check regis model
    expect(await stakingHub.getModelAddresses()).to.be.deep.eq([
      hybridModelAddress,
    ]);

    // Set the balance of the impersonated account
    const hexBalance = "0x" + ethers.parseEther("100").toString(16);
    for await (let i of Array(3).keys()) {
      await ethers.provider.send("hardhat_setBalance", [
        address18[i],
        hexBalance,
      ]);

      let impersonatedSigner = await ethers.getImpersonatedSigner(address18[i]);
      // Wrap EAI
      await wEAI
        .connect(impersonatedSigner)
        .wrap({ value: ethers.parseEther("50") });
      // Approve StakingHub
      await wEAI
        .connect(impersonatedSigner)
        .approve(stakingHubAddress, ethers.parseEther("50"));

      //Regis miner and then join for minting
      await stakingHub.connect(impersonatedSigner).registerMiner(1);

      await stakingHub.connect(impersonatedSigner).joinForMinting();
    }
    expect((await stakingHub.getMinerAddresses()).length).to.eq(3);

    // simulate contract model call to worker hub to create inference
    const hybridModelIns = (await getContractInstance(
      "HybridModel",
      hybridModelAddress
    )) as HybridModel;

    const modelInput = ethers.encodeBytes32String("test");
    let impersonatedUser = await ethers.getImpersonatedSigner(address18[16]);
    // await hybridModelIns
    //   .connect(impersonatedUser)
    //   .infer(modelInput, { value: ethers.parseEther("0.2") });

    await hybridModelIns["infer(bytes)"](modelInput, {
      value: ethers.parseEther("0.2"),
    });

    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await provider.getBlock(blockNumber);
    const blockTime = block?.timestamp || 0;
    // expect inference id to be 1
    expect(await workerHub.inferenceNumber()).to.eq(1);

    const inferInfo = await workerHub.getInferenceInfo(1n);
    //check inference info
    expect(inferInfo.input).to.eq(modelInput);
    expect(inferInfo.modelAddress).to.eq(hybridModelAddress);

    // find the assigned workers
    let assignedMiners: string[] = [];
    const assignIds = await workerHub.getAssignmentsByInference(1n);
    for await (let id of assignIds) {
      const assignInfo = await workerHub.assignments(id);
      assignedMiners.push(assignInfo.worker);
    }

    expect(assignedMiners.length).to.eq(3);

    return assignedMiners;
  }

  describe("WorkerHub contract", async () => {
    it("Should be ok", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        stakingHubAddress,
        wEAIAddress,
      } = await loadFixture(deployWorkerHubFixture);

      // console.log(`proxyLLAMAAddress: ${proxyLLAMAAddress}`);
      // console.log(`proxyWorkerHubAddress: ${proxyWorkerHubAddress}`);
      // console.log(`stakingHubAddress: ${stakingHubAddress}`);
      // console.log(`hybridModelAddress: ${hybridModelAddress}`);
      // console.log(`wEAIAddress: ${wEAIAddress}`);

      const workerHub = (await getContractInstance(
        "WorkerHub",
        proxyWorkerHubAddress
      )) as WorkerHub;

      const assignedMiners = await simulate(
        proxyWorkerHubAddress,
        stakingHubAddress,
        hybridModelAddress,
        wEAIAddress
      );

      expect(assignedMiners.length).to.eq(3);
      console.log(assignedMiners);
    });

    it("Should update agent", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        stakingHubAddress,
        wEAIAddress,
        systemPromptManagerAddress,
      } = await loadFixture(deployWorkerHubFixture);

      const ins = (await getContractInstance(
        "SystemPromptManager",
        systemPromptManagerAddress
      )) as SystemPromptManager;

      console.log("owner: ", await ins.ownerOf(1));
      const [admin1, admin2] = await ethers.getSigners();
      console.log(admin1.address);

      const linkPrompt =
        "ipfs://bafkreide4kf4se2atgdi3kjie5eigvvr3wnkyolitbrj6cuj3sfzfyowui";
      const data = ethers.toUtf8Bytes(linkPrompt);

      const agentId = 1n;
      const promptIdx = 0n;
      const randomBytes = ethers.randomBytes(8);
      const randomNonce = BigInt(
        "0x" + Buffer.from(randomBytes).toString("hex")
      ); // Convert bytes to BigInt

      const address = systemPromptManagerAddress;
      const chainId = 31337n;
      // const chainId = 8453n;

      const coder = AbiCoder.defaultAbiCoder();
      const encodedData = coder.encode(
        ["bytes", "uint256", "uint256", "uint256", "address", "uint256"],
        [data, agentId, promptIdx, randomNonce, address, chainId]
      );
      console.log("encodedData ", [
        data,
        agentId,
        promptIdx,
        randomNonce,
        address,
        chainId,
      ]);

      const hashData = ethers.keccak256(encodedData);
      console.log("hashData ", hashData);
      const signature = await admin.signMessage(ethers.getBytes(hashData));
      const tx = await ins.updateAgentDataWithSignature(
        agentId,
        data,
        promptIdx,
        randomNonce,
        signature
      );

      const tx2 = await ins.updateAgentDataWithSignature(
        agentId,
        data,
        promptIdx,
        randomNonce,
        signature
      );
    });

    it.only("Should update agent uri", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        stakingHubAddress,
        wEAIAddress,
        systemPromptManagerAddress,
      } = await loadFixture(deployWorkerHubFixture);

      const ins = (await getContractInstance(
        "SystemPromptManager",
        systemPromptManagerAddress
      )) as SystemPromptManager;

      console.log("owner: ", await ins.ownerOf(1));
      const [admin1, admin2] = await ethers.getSigners();
      console.log(admin1.address);

      const linkUri =
        "ipfs://bafkreide4kf4se2atgdi3kjie5eigvvr3wnkyolitbrj6cuj3sfzfyowui";

      const agentId = 1n;
      const randomBytes = ethers.randomBytes(8);
      const randomNonce = BigInt(
        "0x" + Buffer.from(randomBytes).toString("hex")
      ); // Convert bytes to BigInt

      const address = systemPromptManagerAddress;
      const chainId = 31337n;
      // const chainId = 8453n;

      const coder = AbiCoder.defaultAbiCoder();
      const encodedData = coder.encode(
        ["string", "uint256", "uint256", "address", "uint256"],
        [linkUri, agentId, randomNonce, address, chainId]
      );

      const hashData = ethers.keccak256(encodedData);
      console.log("hashData ", hashData);
      const signature = await admin.signMessage(ethers.getBytes(hashData));
      const tx = await ins.updateAgentUriWithSignature(
        agentId,
        linkUri,
        randomNonce,
        signature
      );
      ///
      const encodedData2 = coder.encode(
        ["string", "uint256", "uint256", "address", "uint256"],
        [linkUri, 2n, randomNonce, address, chainId]
      );
      const hashData2 = ethers.keccak256(encodedData2);
      const signature2 = await admin.signMessage(ethers.getBytes(hashData2));

      const tx2 = await ins.updateAgentUriWithSignature(
        2n,
        linkUri,
        randomNonce,
        signature2
      );
    });
  });
});

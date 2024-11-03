import { ethers, upgrades, network, Signer } from "hardhat";
import { expect } from "chai";
import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers");

import { address18 } from "./address.seed.js";

import {
  IWorkerHub,
  LLAMA,
  WorkerHub,
  ModelCollection,
  WorkerHubScoring,
  DAOToken,
} from "../typechain-types/index.js";
import { EventLog, wordlists } from "ethers";
import { proxy } from "../typechain-types/@openzeppelin/contracts/index.js";
import { HybridModel } from "../typechain-types/contracts/HybridModel.js";
import { combineDurations } from "../scripts/utils.js";

describe("WorkerHub contract", async () => {
  const { provider } = ethers;
  async function deployWorkerHubFixture() {
    const [admin] = await ethers.getSigners();
    console.log(`admin: ${admin.address}`);

    const proxyLLAMAAddress = await deployDAOToken();
    const modelCollectionAddress = await deployModelCollection();
    const proxyWorkerHubAddress = await deployWorkerHub(proxyLLAMAAddress);
    const hybridModelAddress = await deployHybridModel(
      proxyWorkerHubAddress,
      modelCollectionAddress
    );
    const proxyWorkerHubScoringAddress = await deployWorkerHubScoring(
      proxyLLAMAAddress,
      proxyWorkerHubAddress
    );
    const scoringModelAddress = await deployScoringModel(
      proxyWorkerHubScoringAddress,
      proxyWorkerHubAddress,
      modelCollectionAddress
    );

    return {
      admin,
      proxyLLAMAAddress,
      proxyWorkerHubAddress,
      hybridModelAddress,
      proxyWorkerHubScoringAddress,
      scoringModelAddress,
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

  async function deployWorkerHub(daoTokenAddress: string) {
    const l2OwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    // const daoTokenAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const feeL2Percentage = 10_00;
    const feeTreasuryPercentage = 10_00;
    const minerMinimumStake = ethers.parseEther("0.1");
    const minerRequirement = 3;
    const blockPerEpoch = 600;
    const rewardPerEpoch = ethers.parseEther("0");
    const submitDuration = 10 * 60;
    const commitDuration = 10 * 60;
    const revealDuration = 10 * 60;
    const unstakeDelayTime = 10 * 60;
    const penaltyDuration = 3600;
    const finePercentage = 5_00;
    const feeRatioMinerValidator = 10_00;
    const _minFeeToUse = ethers.parseEther("0.1");
    const _daoTokenReward = ethers.parseEther("0.1");
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
      _minFeeToUse,
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

    return proxyWorkerHubAddress;
  }

  async function deployHybridModel(
    workerHubAddress: string,
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

    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    await workerHub.registerModel(
      proxyAddress,
      minHardware,
      ethers.parseEther("0.1")
    );

    return proxyAddress;
  }

  async function deployWorkerHubScoring(
    daoTokenAddress: string,
    workerHubAddress: string
  ) {
    const l2OwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    // const daoTokenAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const feeL2Percentage = 10_00;
    const feeTreasuryPercentage = 10_00;
    const minerMinimumStake = ethers.parseEther("0.1");
    const minerRequirement = 3;
    const blockPerEpoch = 600;
    const rewardPerEpoch = ethers.parseEther("0");
    const submitDuration = 10 * 60;
    const commitDuration = 10 * 60;
    const revealDuration = 10 * 60;
    const unstakeDelayTime = 10 * 60;
    const penaltyDuration = 3600;
    const finePercentage = 5_00;
    const feeRatioMinerValidator = 10_00;
    const _minFeeToUse = ethers.parseEther("0.1");
    const _daoTokenReward = ethers.parseEther("0.1");
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
      _minFeeToUse,
      _daoTokenReward,
      daoTokenPercentage,
    ];

    const WorkerHubFact = await ethers.getContractFactory("WorkerHubScoring");

    const proxyWorkerHub = await upgrades.deployProxy(
      WorkerHubFact,
      constructorParams
    );
    await proxyWorkerHub.waitForDeployment();
    const proxyWorkerHubScoringAddress = await proxyWorkerHub.getAddress();

    //*************************************************************** */
    const contractFactScoring = await ethers.getContractFactory(
      "WorkerHubScoring"
    );
    const workerHubScoringIns = contractFactScoring.attach(
      proxyWorkerHubScoringAddress
    ) as WorkerHubScoring;
    await workerHubScoringIns.setupScoringVar(workerHubAddress);

    return proxyWorkerHubScoringAddress;
  }

  async function deployScoringModel(
    workerHubScoringAddress: string,
    workerHubAddress: string,
    collectionAddress: string
  ) {
    const identifier = 0;
    const name = "Scoring V2";
    const minHardware = 1;
    const metadataObj = {
      version: 1,
      model_name: "Scoring V2",
      model_type: "Scoring",
      model_url: "",
      model_file_hash: "",
      min_hardware: 1,
      verifier_url: "",
      verifier_file_hash: "",
    };
    const metadata = JSON.stringify(metadataObj, null, "\t");

    const constructorParams = [
      workerHubScoringAddress,
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
    const WorkerHubScoring = await ethers.getContractFactory(
      "WorkerHubScoring"
    );
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
    console.log("workerHubScoringAddress: ", workerHubScoringAddress);

    const workerHubScoring = WorkerHubScoring.attach(
      workerHubScoringAddress
    ) as WorkerHubScoring;
    await workerHubScoring.registerModel(
      proxyAddress,
      minHardware,
      ethers.parseEther("0.1")
    );

    const x = await workerHubScoring.models(proxyAddress);
    console.log("===>Scoring model info: ", x);

    //* *************************************************************** */
    const WorkerHubFact = await ethers.getContractFactory("WorkerHub");
    const workerHub = WorkerHubFact.attach(workerHubAddress) as WorkerHub;
    await workerHub.setScoringInfo(workerHubScoringAddress, proxyAddress);

    return proxyAddress;
  }

  async function simulate(
    workerHubAddress: string,
    workerHubScoringAddress: string,
    hybridModelAddress: string,
    scoringModelAddress: string
  ) {
    const workerHub = await getWorkerHubContract(workerHubAddress);
    const workerHubScoring = (await getContractInstance(
      "WorkerHubScoring",
      workerHubScoringAddress
    )) as WorkerHubScoring;

    const [admin] = await ethers.getSigners();

    //check regis model
    expect(await workerHub.getModelAddresses()).to.be.deep.eq([
      hybridModelAddress,
    ]);
    expect(await workerHubScoring.getModelAddresses()).to.be.deep.eq([
      scoringModelAddress,
    ]);

    // Set the balance of the impersonated account
    const hexBalance = "0x" + ethers.parseEther("100").toString(16);
    for await (let i of Array(18).keys()) {
      await ethers.provider.send("hardhat_setBalance", [
        address18[i],
        hexBalance,
      ]);

      //Regis miner and then join for minting
      let impersonatedSigner = await ethers.getImpersonatedSigner(address18[i]);
      await workerHub
        .connect(impersonatedSigner)
        .registerMiner(1, { value: ethers.parseEther("0.1") });

      await workerHub.connect(impersonatedSigner).joinForMinting();

      await workerHubScoring
        .connect(impersonatedSigner)
        .registerMiner(1, { value: ethers.parseEther("0.1") });

      await workerHubScoring.connect(impersonatedSigner).joinForMinting();
    }
    expect((await workerHub.getMinerAddresses()).length).to.eq(18);
    expect((await workerHubScoring.getMinerAddresses()).length).to.eq(18);

    // simulate contract model call to worker hub to create inference
    const hybridModelIns = (await getContractInstance(
      "HybridModel",
      hybridModelAddress
    )) as HybridModel;

    const modelInput = ethers.encodeBytes32String("test");
    let impersonatedUser = await ethers.getImpersonatedSigner(address18[16]);
    await hybridModelIns
      .connect(impersonatedUser)
      .infer(modelInput, { value: ethers.parseEther("0.2") });

    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await provider.getBlock(blockNumber);
    const blockTime = block?.timestamp || 0;
    // expect inference id to be 1
    expect(await workerHub.inferenceNumber()).to.eq(1);

    const inferInfo = await workerHub.getInferenceInfo(1n);
    //check inference info
    expect(inferInfo.input).to.eq(modelInput);
    expect(inferInfo.modelAddress).to.eq(hybridModelAddress);

    // expect(inferInfo.submitTimeout).to.eq(blockTime + 600);
    // expect(inferInfo.commitTimeout).to.eq(blockTime + 600 * 2);
    // expect(inferInfo.revealTimeout).to.eq(blockTime + 600 * 3);

    // find the assigned workers
    const assigns = await workerHub.getAllAssignments(1n, 3);
    const assignedMiners = assigns.map((a) => a.worker);
    expect(assignedMiners.length).to.eq(3);

    return assignedMiners;
  }

  async function getWorkerHubContract(proxyAddress: string) {
    const contractFact = await ethers.getContractFactory("WorkerHub");
    const workerHub = contractFact.attach(proxyAddress);

    return workerHub as WorkerHub;
  }

  async function getContractInstance(name: string, address: string) {
    const contractFact = await ethers.getContractFactory(name);
    const contractIns = contractFact.attach(address);

    return contractIns;
  }

  describe("WorkerHub contract", async () => {
    it("should deploy WorkerHub contract", async () => {
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );

      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      expect(await workerHub.getAddress()).to.be.properAddress;
    });

    it("should simulate --> create inference + assign task to workers", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        proxyWorkerHubScoringAddress,
        scoringModelAddress,
      } = await loadFixture(deployWorkerHubFixture);

      await simulate(
        proxyWorkerHubAddress,
        proxyWorkerHubScoringAddress,
        hybridModelAddress,
        scoringModelAddress
      );
    });

    it("should seize the miner role", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        proxyWorkerHubScoringAddress,
        scoringModelAddress,
      } = await loadFixture(deployWorkerHubFixture);
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(
        proxyWorkerHubAddress,
        proxyWorkerHubScoringAddress,
        hybridModelAddress,
        scoringModelAddress
      );

      for await (let i of Array(3).keys()) {
        let impersonatedSigner = await ethers.getImpersonatedSigner(
          assignedMiners[i]
        );

        await expect(workerHub.connect(impersonatedSigner).seizeMinerRole(19n))
          .to.be.reverted;

        if (i == 0) {
          const tx = await workerHub
            .connect(impersonatedSigner)
            .seizeMinerRole(1n);
          expect(tx.wait()).to.be.fulfilled;
        } else {
          await expect(
            workerHub.connect(impersonatedSigner).seizeMinerRole(BigInt(i + 1))
          ).to.be.revertedWith("This inference has been seized");
        }
      }

      expect((await workerHub.getAllInferences(1n, 1))[0].processedMiner).to.eq(
        assignedMiners[0]
      );
    });

    it("Should submit solution", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        proxyWorkerHubScoringAddress,
        scoringModelAddress,
      } = await loadFixture(deployWorkerHubFixture);
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(
        proxyWorkerHubAddress,
        proxyWorkerHubScoringAddress,
        hybridModelAddress,
        scoringModelAddress
      );

      let impersonatedSigner = await ethers.getImpersonatedSigner(
        assignedMiners[0]
      );

      await workerHub.connect(impersonatedSigner).seizeMinerRole(1n);

      const solution = ethers.encodeBytes32String("solution for test");

      const tx = await workerHub
        .connect(impersonatedSigner)
        .submitSolution(1n, solution);
      expect(tx.wait()).to.be.fulfilled;

      // try submitting again
      let impersonatedSigner2 = await ethers.getImpersonatedSigner(
        assignedMiners[1]
      );

      await expect(
        workerHub.connect(impersonatedSigner2).submitSolution(2n, solution)
      ).to.be.revertedWithCustomError(workerHub, "InvalidRole()");
    });

    it.only("Should be ok", async () => {
      const {
        admin,
        proxyLLAMAAddress,
        proxyWorkerHubAddress,
        hybridModelAddress,
        proxyWorkerHubScoringAddress,
        scoringModelAddress,
      } = await loadFixture(deployWorkerHubFixture);
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(
        proxyWorkerHubAddress,
        proxyWorkerHubScoringAddress,
        hybridModelAddress,
        scoringModelAddress
      );

      let impersonatedSigner = await ethers.getImpersonatedSigner(
        assignedMiners[0]
      );

      await workerHub.connect(impersonatedSigner).seizeMinerRole(1n);

      const solution = ethers.encodeBytes32String("solution for test");

      const tx = await workerHub
        .connect(impersonatedSigner)
        .submitSolution(1n, solution);
      expect(tx.wait()).to.be.fulfilled;

      // try submitting again
      let impersonatedSigner2 = await ethers.getImpersonatedSigner(
        assignedMiners[1]
      );
      const assignId2 = (
        await workerHub.getAssignmentByMiner(assignedMiners[1])
      )[0].assignmentId;

      const nonce2 = 3;
      const commitment2 = ethers.solidityPackedKeccak256(
        ["uint40", "address", "bytes"],
        [nonce2, assignedMiners[1], solution]
      );

      let impersonatedSigner3 = await ethers.getImpersonatedSigner(
        assignedMiners[2]
      );
      const assignId3 = (
        await workerHub.getAssignmentByMiner(assignedMiners[2])
      )[0].assignmentId;
      const nonce3 = 5;
      const commitment3 = ethers.solidityPackedKeccak256(
        ["uint40", "address", "bytes"],
        [nonce3, assignedMiners[2], solution]
      );

      // Call commit
      await workerHub
        .connect(impersonatedSigner2)
        .commit(assignId2, commitment2);
      await workerHub
        .connect(impersonatedSigner3)
        .commit(assignId3, commitment3);

      // Call reveal
      await workerHub
        .connect(impersonatedSigner2)
        .reveal(assignId2, nonce2, solution);
      await workerHub
        .connect(impersonatedSigner3)
        .reveal(assignId3, nonce3, solution);

      // Check scoring hub
      const workerHubScoring = (await getContractInstance(
        "WorkerHubScoring",
        proxyWorkerHubScoringAddress
      )) as WorkerHubScoring;

      // Get inference id
      const inferenceId = await workerHub.inferenceNumber();
      expect(inferenceId).to.eq(1n);

      // get and compare thee first inference info of worker hub and worker hub scoring
      let inferenceInfo = await workerHub.getInferenceInfo(inferenceId);
      let scoringInferenceInfo = await workerHubScoring.getInferenceInfo(
        inferenceId
      );
      expect(inferenceInfo.creator).to.be.deep.eq(scoringInferenceInfo.creator);
      expect(inferenceInfo.creator).to.be.deep.eq(address18[16]);
      expect(inferenceInfo.input).to.be.deep.eq(scoringInferenceInfo.input);
      expect(inferenceInfo.status).to.be.deep.eq(4);
      expect(inferenceInfo.feeL2).to.be.eq(ethers.parseEther("0.01"));
      expect(inferenceInfo.feeTreasury).to.be.eq(ethers.parseEther("0.01"));
      expect(inferenceInfo.value).to.be.eq(ethers.parseEther("0.08"));
      expect(scoringInferenceInfo.feeL2).to.be.eq(ethers.parseEther("0.01"));
      expect(scoringInferenceInfo.feeTreasury).to.be.eq(
        ethers.parseEther("0.01")
      );
      expect(scoringInferenceInfo.value).to.be.eq(ethers.parseEther("0.08"));
      //
      const assigns = await workerHubScoring.getAllAssignments(1n, 3);
      const assignedScoringMiners = assigns.map((a) => a.worker);
      expect(assignedScoringMiners.length).to.eq(3);

      let impersonatedSignerScore1 = await ethers.getImpersonatedSigner(
        assignedScoringMiners[0]
      );
      let impersonatedSignerScore2 = await ethers.getImpersonatedSigner(
        assignedScoringMiners[1]
      );
      let impersonatedSignerScore3 = await ethers.getImpersonatedSigner(
        assignedScoringMiners[2]
      );

      await workerHubScoring
        .connect(impersonatedSignerScore1)
        .seizeMinerRole(1n);

      // const solutionScore = ethers.encodeBytes32String("10");
      const solutionScore = ethers.hexlify("0x0A");
      console.log("solutionScore: ", solutionScore);
      const txScore = await workerHubScoring
        .connect(impersonatedSignerScore1)
        .submitSolution(1n, solutionScore);

      expect(txScore.wait()).to.be.fulfilled;

      // Prepare for commitment
      const assignScoreId2 = (
        await workerHubScoring.getAssignmentByMiner(assignedScoringMiners[1])
      )[0].assignmentId;

      const nonceScore2 = 3;
      const commitmentScore2 = ethers.solidityPackedKeccak256(
        ["uint40", "address", "bytes"],
        [nonceScore2, assignedScoringMiners[1], solutionScore]
      );

      const assignScoreId3 = (
        await workerHubScoring.getAssignmentByMiner(assignedScoringMiners[2])
      )[0].assignmentId;
      const nonceScore3 = 5;
      const commitmentScore3 = ethers.solidityPackedKeccak256(
        ["uint40", "address", "bytes"],
        [nonceScore3, assignedScoringMiners[2], solutionScore]
      );

      // Call commit
      await workerHubScoring
        .connect(impersonatedSignerScore2)
        .commit(assignScoreId2, commitmentScore2);
      await workerHubScoring
        .connect(impersonatedSignerScore3)
        .commit(assignScoreId3, commitmentScore3);

      // Call reveal
      await workerHubScoring
        .connect(impersonatedSignerScore2)
        .reveal(assignScoreId2, nonceScore2, solutionScore);
      await workerHubScoring
        .connect(impersonatedSignerScore3)
        .reveal(assignScoreId3, nonceScore3, solutionScore);

      //
      const userAddress = inferenceInfo.creator;
      const daoToken = (await getContractInstance(
        "DAOToken",
        proxyLLAMAAddress
      )) as DAOToken;
      const userBalance = await daoToken.balanceOf(userAddress);
      expect(userBalance).to.be.eq(ethers.parseEther("0.03"));
      inferenceInfo = await workerHub.getInferenceInfo(inferenceId);
      scoringInferenceInfo = await workerHubScoring.getInferenceInfo(
        inferenceId
      );
      expect(inferenceInfo.status).to.be.deep.eq(6);
      expect(scoringInferenceInfo.status).to.be.deep.eq(4);
    });
  });
});

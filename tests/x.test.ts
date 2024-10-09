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
  WorkerHub__factory,
} from "../typechain-types";
import { wordlists } from "ethers";

describe("WorkerHub contract", async () => {
  const { provider } = ethers;
  async function deployWorkerHubFixture() {
    const [admin] = await ethers.getSigners();
    console.log(`admin: ${admin.address}`);

    const l2OwnerAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const treasuryAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
    const daoTokenAddress = "0xb9Ec1345357A10CFc3C43d7455238881048d1f63";
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
      submitDuration,
      commitDuration,
      revealDuration,
      unstakeDelayTime,
      penaltyDuration,
      finePercentage,
      feeRatioMinerValidator,
      _minFeeToUse,
      _daoTokenReward,
      daoTokenPercentage,
    ];

    //*************************************************************** */
    console.log("WorkerHub.deploying ...");
    const WorkerHubFact = await ethers.getContractFactory("WorkerHub");

    const proxyWorkerHub = await upgrades.deployProxy(
      WorkerHubFact,
      constructorParams
    );
    await proxyWorkerHub.waitForDeployment();
    const proxyWorkerHubAddress = await proxyWorkerHub.getAddress();

    // Deploy LLAMA token contract
    const LLAMAFact = await ethers.getContractFactory("LLAMA");

    const proxyLLAMA = await upgrades.deployProxy(LLAMAFact, [
      proxyWorkerHubAddress,
    ]);
    await proxyLLAMA.waitForDeployment();
    const proxyLLAMAAddress = await proxyLLAMA.getAddress();
    //
    const contractFact = await ethers.getContractFactory("LLAMA");
    const LLAMAIns = contractFact.attach(proxyLLAMAAddress) as LLAMA;
    await LLAMAIns.updateMaxSupply();

    //
    const wokerhub = await getWorkerHubContract(proxyWorkerHubAddress);
    await wokerhub.setDAOToken(proxyLLAMAAddress);

    //
    return {
      admin,
      proxyWorkerHubAddress,
      proxyLLAMAAddress,
    };
  }

  async function simulate(wokerHubAddress: string) {
    const workerHub = await getWorkerHubContract(wokerHubAddress);

    const [admin] = await ethers.getSigners();

    //regis model
    const fee = ethers.parseEther("0.1");
    await workerHub.connect(admin).registerModel(address18[17], 1, fee);

    expect(await workerHub.getModelAddresses()).to.be.deep.eq([address18[17]]);

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
    }

    expect((await workerHub.getMinerAddresses()).length).to.eq(18);

    // simulate contract model call to workerhub to create inference

    const modelAddress = address18[17];
    const modelInput = ethers.encodeBytes32String("test");
    let impersonatedModel = await ethers.getImpersonatedSigner(modelAddress);
    await workerHub
      .connect(impersonatedModel)
      .infer(modelInput, address18[16], { value: ethers.parseEther("0.2") });

    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await provider.getBlock(blockNumber);
    const blockTime = block?.timestamp || 0;
    // expect inference id to be 1
    expect(await workerHub.inferenceNumber()).to.eq(1);

    const inferInfo = await workerHub.getInferenceInfo(1n);
    //check inference info
    expect(inferInfo.input).to.eq(modelInput);
    expect(inferInfo.modelAddress).to.eq(modelAddress);
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

  describe("WorkerHub contract", async () => {
    it("should deploy WorkerHub contract", async () => {
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );

      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      expect(await workerHub.getAddress()).to.be.properAddress;
    });

    it("should simulate --> create inference + assign task to workers", async () => {
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );

      await simulate(proxyWorkerHubAddress);
    });

    it("should seize the miner role", async () => {
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(proxyWorkerHubAddress);

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
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(proxyWorkerHubAddress);

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
      const { admin, proxyWorkerHubAddress } = await loadFixture(
        deployWorkerHubFixture
      );
      const workerHub = await getWorkerHubContract(proxyWorkerHubAddress);

      const assignedMiners = await simulate(proxyWorkerHubAddress);

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
    });
  });
});

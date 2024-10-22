import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";
import { HybridModel } from "../typechain-types/contracts/HybridModel";
import { WorkerHubScoring } from "../typechain-types/contracts/WorkerHubScoring";

async function getWorkerHubContract(proxyAddress: string) {
  const contractFact = await ethers.getContractFactory("WorkerHub");
  const workerHub = contractFact.attach(proxyAddress);

  return workerHub as WorkerHub;
}
async function workerHubUpdateInfo() {
  const config = network.config as any;
  const workerhub = await getWorkerHubContract(config.workerHubAddress);
  console.log("Worker Hub address: ", config.workerHubAddress);

  const reward = ethers.parseEther("10");
  const tx = await workerhub.setDAOTokenReward(reward);
  const receipt = await tx.wait();
  console.log("Transaction hash: ", receipt?.hash);
  console.log("Transaction status: ", receipt?.status);
}

async function createInfer() {
  const config = network.config as any;
  const user = (await ethers.getSigners())[0];

  const workerhub = await getWorkerHubContract(config.workerHubAddress);
  const HybridModel = await ethers.getContractFactory("HybridModel");
  const model = HybridModel.attach(
    "0x355c5F5ffA7e8a7DCE1Dc21f7453756a128C9bA4"
  ) as HybridModel;

  const tx = await model
    .connect(user)
    .infer("0x3756", { value: ethers.parseEther("0.1") });

  const rep = await tx.wait();
  console.log("Transaction hash: ", rep?.hash);
  console.log("Transaction status: ", rep?.status);
}

async function main() {
  const config = network.config as any;
  const user = (await ethers.getSigners())[0];

  const workerhub = await getWorkerHubContract(config.workerHubAddress);
  const scoreModel = "0x9B77a037C21FE9A7A821f4FF858eb0b3e83235a4";
  const scoreHub = config.workerHubScoringAddress;
  const tx = await workerhub.setScoringInfo(scoreHub, scoreModel);
  const rp = await tx.wait();
  console.log("update info scorre: ", rp?.hash);
  console.log("update info scorre: ", rp?.status);
}

createInfer()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

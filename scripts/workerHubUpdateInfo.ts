import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";

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

workerHubUpdateInfo()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

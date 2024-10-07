import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";

async function getWorkerHubContract(proxyAddress: string) {
  const contractFact = await ethers.getContractFactory("WorkerHub");
  const workerHub = contractFact.attach(proxyAddress);

  return workerHub as WorkerHub;
}
async function workerHubUpdatePenaltyParams() {
  const config = network.config as any;
  const workerhub = await getWorkerHubContract(config.workerHubAddress);
  console.log("Workerhub address: ", config.workerHubAddress);

  console.log("WorkerHub set penalty duration...");
  const tx1 = await workerhub.setPenaltyDuration(0);
  const receipt1 = await tx1.wait();
  console.log("Transaction hash: ", receipt1?.hash);
  console.log("Transaction status: ", receipt1?.status);

  console.log("WorkerHub set penalty percentage...");
  const tx2 = await workerhub.setFinePercentage(0);
  const receipt2 = await tx2.wait();
  console.log("Transaction hash: ", receipt2?.hash);
  console.log("Transaction status: ", receipt2?.status);
}

workerHubUpdatePenaltyParams()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

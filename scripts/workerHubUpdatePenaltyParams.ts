import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";

async function getWorkerHubContract(proxyAddress: string) {
  const contractFact = await ethers.getContractFactory("WorkerHub");
  const workerHub = contractFact.attach(proxyAddress);

  return workerHub as WorkerHub;
}
async function workerHubUpdateParamsx() {
  const config = network.config as any;
  const workerhub = await getWorkerHubContract(config.workerHubAddress);
  console.log("Workerhub address: ", config.workerHubAddress);

  console.log("WorkerHub set submit duration...");
  const tx1 = await workerhub.setSubmitDuration(1500);
  const receipt1 = await tx1.wait();
  console.log("Transaction hash: ", receipt1?.hash);
  console.log("Transaction status: ", receipt1?.status);

  console.log("WorkerHub set commit duration...");
  const tx2 = await workerhub.setCommitDuration(1500);
  const receipt2 = await tx2.wait();
  console.log("Transaction hash: ", receipt2?.hash);
  console.log("Transaction status: ", receipt2?.status);

  console.log("WorkerHub set reveal duration...");
  const tx3 = await workerhub.setRevealDuration(1500);
  const receipt3 = await tx3.wait();
  console.log("Transaction hash: ", receipt3?.hash);
  console.log("Transaction status: ", receipt3?.status);
}

workerHubUpdateParamsx()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

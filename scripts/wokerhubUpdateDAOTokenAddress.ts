import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";

async function getWorkerHubContract(proxyAddress: string) {
  const contractFact = await ethers.getContractFactory("WorkerHub");
  const workerHub = contractFact.attach(proxyAddress);

  return workerHub as WorkerHub;
}
async function workerHubUpdateDAOTokenAddress() {
  console.log("Updating DAO Token Address ...");
  const config = network.config as any;
  const workerhub = await getWorkerHubContract(config.workerHubAddress);

  const llamaTokenAddress = config.llamaTokenAddress;
  console.log("llamaToken address: ", llamaTokenAddress);
  console.log("Workerhub address: ", config.workerHubAddress);

  const tx = await workerhub.setDAOToken(llamaTokenAddress);
  const receipt = await tx.wait();
  console.log("Transaction hash: ", receipt?.hash);
  console.log("Transaction status: ", receipt?.status);
}

workerHubUpdateDAOTokenAddress()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

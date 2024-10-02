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
  console.log("Workerhub address: ", config.workerHubAddress);

  // Update llama token address
  const llamaTokenAddress = config.llamaTokenAddress;
  console.log("Updating DAO Token Address ...");
  console.log("llamaToken address: ", llamaTokenAddress);

  const tx1 = await workerhub.setDAOToken(llamaTokenAddress);
  const receipt1 = await tx1.wait();
  console.log("Transaction hash: ", receipt1?.hash);
  console.log("Transaction status: ", receipt1?.status);

  // Update treasury address
  const treasuryAddress = config.treasuryAddress;
  console.log("Updating treasury address  ...");
  console.log("treasury address: ", treasuryAddress);

  const tx2 = await workerhub.setTreasuryAddress(treasuryAddress);
  const receipt2 = await tx2.wait();
  console.log("Transaction hash: ", receipt2?.hash);
  console.log("Transaction status: ", receipt2?.status);
}

workerHubUpdateInfo()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

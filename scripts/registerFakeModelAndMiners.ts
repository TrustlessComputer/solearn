import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";
import { deployOrUpgrade } from "./lib/utils";

async function registerFakeMiners() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const collectionAddress = config.collectionAddress;
  assert.ok(
      collectionAddress,
      `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
  );

  const workerHubAddress = config.workerHubAddress;
  assert.ok(
      workerHubAddress,
      `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const collection = await ethers.getContractAt("ModelCollection", collectionAddress);
  const workerHub = await ethers.getContractAt("WorkerHub", workerHubAddress);

  const stakeTokenAddress = await workerHub.stakeToken();
  const stokeToken = await ethers.getContractAt("ERC20", workerHubAddress);

  const accounts = await ethers.getSigners()
  const [model, ...miners] = accounts[0];


  

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHub.target}`);
}

registerFakeMiners()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

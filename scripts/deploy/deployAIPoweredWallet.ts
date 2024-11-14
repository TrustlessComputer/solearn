import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import {
  AIPoweredWallet,
  DAOToken,
  IWorkerHub,
  LLAMA,
  WorkerHub,
} from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployAIPoweredWallet() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const hybridModelAddress = config.hybridModelAddress;
  const workerHubAddress = config.workerHubAddress;
  assert.ok(
    hybridModelAddress,
    `Missing ${networkName}_HYBRID_MODEL_ADDRESS from environment variables!`
  );
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const fact = await ethers.getContractFactory("AIPoweredWallet");
  const aiPoweredWallet = await fact.deploy(
    hybridModelAddress,
    workerHubAddress
  );
  await aiPoweredWallet.waitForDeployment();

  console.log(
    `${networkName}_AI_POWERED_WALLET_ADDRESS=${aiPoweredWallet.target}`
  );
}

async function suspiciousTransaction() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const address = "0x1E6702fC1eE72496dd9ECFdd7961a958d793E7DB";

  const fact = await ethers.getContractFactory("AIPoweredWallet");
  const aiPoweredWallet = fact.attach(address) as AIPoweredWallet;
  // const tx = await aiPoweredWallet.send(
  //   "0x62998e172240F4CC26EC10717d16a8D4442bf2Dd",
  //   { value: ethers.parseEther("0.00095") }
  // );
  // const tx = await aiPoweredWallet.suspiciousTransaction();
  // const res = await tx.wait();
  // console.log(res?.hash);
  // console.log(res?.status);

  console.log(await aiPoweredWallet.currentInferenceId());
  console.log(await aiPoweredWallet.fetchInferenceResult(307n));
}

deployAIPoweredWallet()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

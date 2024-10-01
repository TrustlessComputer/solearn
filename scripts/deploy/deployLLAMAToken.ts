import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { IWorkerHub, LLAMA, WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployLLAMAToken() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const workerHubAddress = config.workerHubAddress;
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const llamaToken = (await deployOrUpgrade(
    config.llamaTokenAddress,
    "LLAMA",
    [workerHubAddress],
    config,
    true
  )) as unknown as LLAMA;

  console.log(`${networkName}_LLAMA_TOKEN_ADDRESS=${llamaToken.target}`);
}

deployLLAMAToken()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

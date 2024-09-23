import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WETH9, WorkerHub } from "../../typechain-types";
import { deployContract, deployOrUpgrade } from "../lib/utils";

async function deployWETH9() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const weth9 = (await deployContract(
    "WETH9"
  ) as unknown) as WETH9;

  console.log(`${networkName}_WORKER_HUB_ADDRESS=${weth9.target}`);
}

deployWETH9()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { IWorkerHub, Treasury, WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployTreasury() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const llamaTokenAddress = config.llamaTokenAddress;
  const treasuryAddress = config.treasuryAddress;
  assert.ok(
    llamaTokenAddress,
    `Missing ${networkName}_LLAMA_TOKEN_ADDRESS from environment variables!`
  );

  const constructorParams = [llamaTokenAddress];

  const treasury = (await deployOrUpgrade(
    config.treasuryAddress,
    "Treasury",
    constructorParams,
    config,
    true
  )) as unknown as Treasury;

  console.log(`${networkName}_TREASURY_ADDRESS=${treasury.target}`);
}

deployTreasury()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

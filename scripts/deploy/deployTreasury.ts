import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { IWorkerHub, Treasury, WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployTreasury() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const daoTokenAddress = config.daoTokenAddress;
  const treasuryAddress = config.treasuryAddress;
  assert.ok(
    daoTokenAddress,
    `Missing ${networkName}_DAO_TOKEN_ADDRESS from environment variables!`
  );

  const constructorParams = [daoTokenAddress];

  const treasury = (await deployOrUpgrade(
    treasuryAddress,
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

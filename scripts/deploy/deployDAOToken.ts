import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { DAOToken, IWorkerHub, LLAMA, WorkerHub } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deployDAOToken() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const _MAX_SUPPLY_CAP = ethers.parseEther("2100000000"); //2,1B
  const tokenName = "FLUX";
  const tokenSymbol = "FLUX";
  const initializedParams = [tokenName, tokenSymbol, _MAX_SUPPLY_CAP];

  const daoToken = (await deployOrUpgrade(
    config.daoTokenAddress,
    "DAOToken",
    initializedParams,
    config,
    true
  )) as unknown as DAOToken;

  console.log(`${networkName}_DAO_TOKEN_ADDRESS=${daoToken.target}`);
}

deployDAOToken()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import {
  HybridModel,
  ModelCollection,
  SystemPromptManager,
  WorkerHub,
} from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";

async function deploySystemPromptManager() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const l2OwnerAddress = config.l2OwnerAddress;
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = l2OwnerAddress;
  const royalPortion = 5_00;
  const nextModelId = 1; //TODO: need to change before deployment
  const hybridModelAddress = config.hybridModelAddress;
  const workerHubAddress = config.workerHubAddress;

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    hybridModelAddress,
    workerHubAddress,
  ];

  const sysPromptManager = (await deployOrUpgrade(
    config.systemPromptManagerAddress,
    "SystemPromptManager",
    constructorParams,
    config,
    true
  )) as unknown as SystemPromptManager;

  console.log(
    `${networkName}_SYSTEM_PROMPT_MANAGER_ADDRESS=${sysPromptManager.target}`
  );
}

deploySystemPromptManager()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

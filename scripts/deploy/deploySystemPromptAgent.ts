import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import {
  HybridModel,
  ModelCollection,
  SystemPromptAgent,
  WorkerHub,
} from "../../typechain-types";
import { EventLog, Log } from "ethers";
import { deployOrUpgrade } from "../lib/utils";

async function deploySystemPromptAgent() {
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
  const nextModelId = 300_001; //TODO: need to change before deployment
  const hybridModelAddress = config.hybridModelAddress;

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
    hybridModelAddress,
  ];

  const sysPromptAgent = (await deployOrUpgrade(
    config.collectionAddress,
    "SystemPromptAgent",
    constructorParams,
    config,
    true
  )) as unknown as SystemPromptAgent;

  console.log(
    `${networkName}_SYSTEM_PROMPT_AGENT_ADDRESS=${sysPromptAgent.target}`
  );
}

deploySystemPromptAgent()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

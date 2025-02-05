import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { SystemPromptManager } from "../typechain-types";

async function updateAgentPrompt() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const systemPromptManagerAddress = config.systemPromptManagerAddress;
  assert.ok(
    systemPromptManagerAddress,
    `Missing ${networkName}_SYSTEM_PROMPT_MANAGER_ADDRESS from environment variables!`
  );

  // get the contract instance
  const Fact = await ethers.getContractFactory("SystemPromptManager");
  const ins = Fact.attach(systemPromptManagerAddress) as SystemPromptManager;

  // TODO: @mr 6789 fill it
  // ***************************
  const linkPrompt = "";
  const agentId = 1n;
  // ***************************
  const promptIndex = 0n;
  const data = ethers.toUtf8Bytes(linkPrompt);

  const txUpdatePrompt = await ins.updateAgentData(agentId, data, promptIndex);
  const receiptUpdatePrompt = await txUpdatePrompt.wait();
  console.log(`Update Prompt tx hash: ${receiptUpdatePrompt?.hash}`);
  console.log(`Update Prompt status: ${receiptUpdatePrompt?.status}`);

  // get the uri from system prompt manager contract
  const agentPrompt = await ins.getAgentSystemPrompt(agentId);
  console.log("=====================================");
  console.log("New agent prompt: ", agentPrompt[0]);
  console.log(
    "New agent prompt (string): ",
    ethers.toUtf8String(agentPrompt[0])
  );
}

updateAgentPrompt()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

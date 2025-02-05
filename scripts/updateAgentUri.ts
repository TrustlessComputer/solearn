import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { SystemPromptManager } from "../typechain-types";

async function updateAgentUri() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const systemPromptManagerAddress = config.systemPromptManagerAddress;
  assert.ok(
    systemPromptManagerAddress,
    `Missing ${networkName}_SYSTEM_PROMPT_MANAGER_ADDRESS from environment variables!`
  );

  // get the contract instance
  const Fact = await ethers.getContractFactory("SystemPromptManager");
  const ins = Fact.attach(
    config.systemPromptManagerAddress
  ) as SystemPromptManager;

  // TODO: @mr 6789 fill it
  // ***************************
  const uri =
    "ipfs://bafkreih2hzkvh5zup3jbrfatbvoyasxtnq2slkkoeotdpwdg3pqiipwery";
  const agentId = 1n;
  // ***************************

  const txUpdateUri = await ins.updateAgentURI(agentId, uri);
  const receiptUpdateUri = await txUpdateUri.wait();

  console.log(`Update URI tx hash: ${receiptUpdateUri?.hash}`);
  console.log(`Update URI status: ${receiptUpdateUri?.status}`);

  // get the uri from system prompt manager contract
  const agentUri = await ins.tokenURI(agentId);
  console.log("=====================================");
  console.log("New agent URI: ", agentUri);
}

updateAgentUri()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

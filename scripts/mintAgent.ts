import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import { SystemPromptManager } from "../typechain-types";

async function mintAgent() {
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
  const agentOwnerAddress = "";
  const linkUri = "";
  const linkPrompt = "";
  const usageFee = 0;
  // ***************************
  const data = ethers.toUtf8Bytes(linkPrompt);

  const txMint = await ins["mint(address,string,bytes,uint256)"](
    agentOwnerAddress,
    linkUri,
    data,
    usageFee
  );
  const receipt = await txMint.wait();
  console.log(`Update Prompt tx hash: ${receipt?.hash}`);
  console.log(`Update Prompt status: ${receipt?.status}`);
}

mintAgent()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

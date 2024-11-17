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
  const hybridModelAddress = config.hybridModelAddress;
  const workerHubAddress = config.workerHubAddress;
  const systemPromptHelperAddress = config.systemPromptHelperAddress;
  const systemPromptManagerAddress = config.systemPromptManagerAddress;

  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(
    l2OwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );
  assert.ok(
    hybridModelAddress,
    `Missing ${networkName}_HYBRID_MODEL_ADDRESS from environment variables!`
  );
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );
  assert.ok(
    systemPromptHelperAddress,
    `Missing ${networkName}_SYSTEM_PROMPT_HELPER_ADDRESS from environment variables!`
  );

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = l2OwnerAddress;
  const royalPortion = 5_00;
  const nextModelId = 1; //TODO: need to change before deployment

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

  // const sysPromptManager = (await deployOrUpgrade(
  //   config.systemPromptManagerAddress,
  //   "SystemPromptManager",
  //   constructorParams,
  //   config,
  //   true
  // )) as unknown as SystemPromptManager;

  const fact = await ethers.getContractFactory("SystemPromptManager", {
    libraries: {
      SystemPromptHelper: systemPromptHelperAddress,
    },
  });
  let sysPromptManager;

  if (!systemPromptManagerAddress) {
    sysPromptManager = await upgrades.deployProxy(fact, constructorParams);
    await sysPromptManager.waitForDeployment();
  } else {
    sysPromptManager = await upgrades.upgradeProxy(
      systemPromptManagerAddress,
      fact
    );
    await sysPromptManager.waitForDeployment();
  }

  console.log(
    `${networkName}_SYSTEM_PROMPT_MANAGER_ADDRESS=${sysPromptManager.target}`
  );

  // // Mint
  // const Fact = await ethers.getContractFactory("SystemPromptManager");
  // const ins = Fact.attach(sysPromptManager.target) as SystemPromptManager;
  // //
  // const metadataObj = {
  //   agent_uri: "ipfs://meta",
  // };
  // const metadata = JSON.stringify(metadataObj, null, "\t");
  // const linkPrompt = "ifps://systemprompt";

  // const nftOwner = (await ethers.getSigners())[0].address;
  // const uri = metadata;
  // const data = ethers.toUtf8Bytes(linkPrompt);
  // const fee = ethers.parseEther("0");
  // const txMint = await ins.mint(nftOwner, uri, data, fee);
  // const res = await txMint.wait();
  // console.log(`Minted tx hash: ${res?.hash}`);
  // console.log(`Minted status: ${res?.status}`);
  // //
  // const txTopup = await ins.topUpPoolBalance(1n, {
  //   value: ethers.parseEther("20"),
  // });
  // const resTopup = await txTopup.wait();
  // console.log(`Topup tx hash: ${resTopup?.hash}`);
  // console.log(`Topup status: ${resTopup?.status}`);
}

deploySystemPromptManager()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

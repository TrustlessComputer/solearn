import assert from "assert";
import { ethers, network, upgrades } from "hardhat";

async function deployAIPoweredWallet() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const aiKernelAddress = config.hybridModelAddress;
  const promptScheduler = config.workerHubAddress;

  assert.ok(
    aiKernelAddress,
    `Missing ${networkName}_HYBRID_MODEL_ADDRESS from environment variables!`
  );
  assert.ok(
    promptScheduler,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const contractFactory = await ethers.getContractFactory("AIPoweredWallet");
  const aiPoweredWallet = await contractFactory.deploy(
    aiKernelAddress,
    promptScheduler
  );
  await aiPoweredWallet.waitForDeployment();

  console.log(
    `${networkName}_AI_POWERED_WALLET_ADDRESS=${aiPoweredWallet.target}`
  );
}

deployAIPoweredWallet()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

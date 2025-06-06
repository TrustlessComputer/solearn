import { ethers, network, upgrades } from "hardhat";
import { AgentFactory } from "../../typechain-types";
import { deployOrUpgrade } from "../lib/utils";
import * as hre from "hardhat";

async function deployFactoryAndAgentImpl() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  // deploy agent impl
  const agentUpgradeable = await hre.ethers.getContractFactory("AgentUpgradeable");
  const agentUpgradeableImpl = await agentUpgradeable.deploy();
  await agentUpgradeableImpl.waitForDeployment();

  console.log(`${networkName}_AGENT_UPGRADEABLE_IMPL_ADDRESS=${agentUpgradeableImpl.target}`);

  // params
  const constructorParams = [
    "0x1D272FcA4EAdCc2d68072018A43cDdFfC00cADdE", // owner
    agentUpgradeableImpl.target // implementation
  ];

  // deploy factory
  const factory = await deployOrUpgrade(
    config.factoryAddress,
    "AgentFactory",
    constructorParams,
    config,
    true
  ) as unknown as AgentFactory;

  console.log(`${networkName}_FACTORY_ADDRESS=${factory.target}`);
}

deployFactoryAndAgentImpl()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

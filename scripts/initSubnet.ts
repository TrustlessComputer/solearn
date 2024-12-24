import { ethers, network, upgrades } from "hardhat";
import {
  HybridModel,
  ModelLoadBalancer,
  StakingHub,
  WorkerHub,
  WrappedEAI,
} from "../typechain-types";
import { getContract } from "./lib/utils";
import { assert } from "chai";

const config = network.config as any;
const networkName = network.name.toUpperCase();

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

async function main() {
  assert.ok(
    config.modelLoadBalancer,
    "ModelLoadBalancer address not found in config"
  );

  const ins = (await getContractInstance(
    config.modelLoadBalancer,
    "ModelLoadBalancer"
  )) as ModelLoadBalancer;

  // create group
  const grName = "subnet1";
  const listModelAddresses: string[] = [];
  const tx = await ins.createGroup(grName, listModelAddresses);
  const receipt = await tx.wait();
  console.log("Group created: ", grName, " tx hash: ", receipt?.hash);
  console.log("Subnet of group: ", await ins.getSubnetsOfGroup(grName));
}

(async function getMetadata() {
  const models = [
    config.hybridModelAddress_1,
    config.hybridModelAddress_2,
    config.hybridModelAddress_3,
    config.hybridModelAddress_4,
  ];

  for await (let model of models) {
    const ins = (await getContractInstance(
      model,
      "HybridModel"
    )) as HybridModel;

    // get metadata
    const metadata = await ins.metadata();
    console.log(`Model ${model} - ${metadata}: \n\n`);
  }
})();

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

(async function main() {
  assert.ok(
    config.modelLoadBalancer,
    "ModelLoadBalancer address not found in config"
  );

  const ins = (await getContractInstance(
    config.modelLoadBalancer,
    "ModelLoadBalancer"
  )) as ModelLoadBalancer;

  // create group
  // const grName = "NousResearch/Hermes-3-Llama-3.1-70B-FP8";
  // const grName = "neuralmagic/Meta-Llama-3.1-405B-Instruct-quantized.w4a16";
  const grName = "lmstudio-community/INTELLECT-1-Instruct-GGUF";

  // const listModelAddresses: string[] = [
  //   "0x643c45e89769a16bcb870092bd1efe4696cb2ce7",
  // ];
  // const listModelAddresses: string[] = [
  //   "0x9a35863baf0df7623f34fcf3376cdbac8581e76b",
  // ];
  const listModelAddresses: string[] = [
    "0xF5A162E8169CAB83478283B4e36F50b80C0b33F2",
    "0x1A9C75eF8E85A5D4E98B1E35239Ba98cfad1ee93",
  ];
  const tx = await ins.createGroup(grName, listModelAddresses);
  const receipt = await tx.wait();
  console.log("Group created: ", grName, " tx hash: ", receipt?.hash);
  console.log("Cluster of group: ", await ins.getClustersOfGroup(grName));
})();

// (async function getMetadata() {
//   const models = [
//     config.hybridModelAddress_1,
//     config.hybridModelAddress_2,
//     config.hybridModelAddress_3,
//     config.hybridModelAddress_4,
//   ];

//   for await (let model of models) {
//     const ins = (await getContractInstance(
//       model,
//       "HybridModel"
//     )) as HybridModel;

//     // get metadata
//     const metadata = await ins.metadata();
//     console.log(`Model ${model} - ${metadata}: \n\n`);
//   }
// })();

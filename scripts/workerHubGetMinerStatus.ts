import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { WorkerHub } from "../typechain-types";
import { HybridModel } from "../typechain-types/contracts/HybridModel";
import { WorkerHubScoring } from "../typechain-types/contracts/WorkerHubScoring";

async function getWorkerHubContract(proxyAddress: string) {
  const contractFact = await ethers.getContractFactory("WorkerHub");
  const workerHub = contractFact.attach(proxyAddress);

  return workerHub as WorkerHub;
}

async function checkUnregistration(workerHub: WorkerHub, minerAddress: string) {
  const filter = workerHub.filters.MinerUnregistration()
  const events = await workerHub.queryFilter(filter)
  const event = events.filter(x => x.args[0].toLowerCase() == minerAddress.toLowerCase())
  console.log(event);
}

async function checkUnstake(workerHub: WorkerHub, minerAddress: string) {
  const filter = workerHub.filters.MinerUnstake()
  const events = await workerHub.queryFilter(filter)
  const event = events.filter(x => x.args[0].toLowerCase() == minerAddress.toLowerCase())
  console.log(event);
}

async function checkJoinForMinting(workerHub: WorkerHub, minerAddress: string) {
  const filter = workerHub.filters.MinerJoin()
  const events = await workerHub.queryFilter(filter)
  const event = events.filter(x => x.args[0].toLowerCase() == minerAddress.toLowerCase())
  console.log(event);
}

async function main() {
  const config = network.config as any;
  const user = (await ethers.getSigners())[0];

  const workerHub = await getWorkerHubContract(config.workerHubAddress);

  const minerAddress = "0x30e670E7D02C18D602701bfc24387Ad5E60791E7";

  console.log(minerAddress);
  console.log(await workerHub.miners(minerAddress));

  await checkUnstake(workerHub, minerAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

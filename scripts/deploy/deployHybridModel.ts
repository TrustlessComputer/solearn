import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import {
  HybridModel,
  ModelCollection,
  WorkerHub,
  StakingHub,
} from "../../typechain-types";
import { EventLog, Log } from "ethers";
import { deployOrUpgrade } from "../lib/utils";

async function deployHybridModel() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const StakingHub = await ethers.getContractFactory("StakingHub");
  const ModelCollection = await ethers.getContractFactory("ModelCollection");

  const collectionAddress = config.collectionAddress;
  assert.ok(
    collectionAddress,
    `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
  );

  const workerHubAddress = config.workerHubAddress;
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const stakingHubAddress = config.stakingHubAddress;
  assert.ok(
    stakingHubAddress,
    `Missing ${networkName}_STAKING_HUB_ADDRESS from environment variables!`
  );

  const modelOwnerAddress = config.l2OwnerAddress;
  assert.ok(
    modelOwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const identifier = 0;
  const name = "Hermes";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "Hermes",
    model_type: "text",
    model_url: "",
    model_file_hash: "",
    min_hardware: 1,
    verifier_url: "",
    verifier_file_hash: "",
  };
  const metadata = JSON.stringify(metadataObj, null, "\t");
  console.log(metadata);

  const constructorParams = [
    workerHubAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];
  const hybridModel = (await deployOrUpgrade(
    config.hybridModelAddress_2,
    "HybridModel",
    constructorParams,
    config,
    true
  )) as unknown as HybridModel;

  console.log(
    `Contract HybridModel has been deployed to address ${hybridModel.target}`
  );

  if (!config.hybridModelAddress_2) {
    const collection = ModelCollection.attach(
      config.collectionAddress
    ) as ModelCollection;
    const mintReceipt = await (
      await collection.mint(modelOwnerAddress, metadata, hybridModel.target)
    ).wait();

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find(
      (event: EventLog) => event.eventName === "NewToken"
    );
    if (newTokenEvent) {
      console.log("tokenId:", newTokenEvent.args?.tokenId);
    }

    const stakingHub = StakingHub.attach(stakingHubAddress) as StakingHub;
    await stakingHub.registerModel(
      hybridModel.target,
      minHardware,
      ethers.parseEther("0.1")
    );

    console.log(`Contract HybridModel is registered to WorkerHub`);
  }

  console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.target}`);
}

deployHybridModel()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

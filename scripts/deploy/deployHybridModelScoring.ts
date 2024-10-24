import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import {
  HybridModel,
  ModelCollection,
  WorkerHubScoring,
  WorkerHub,
} from "../../typechain-types";
import { EventLog, Log } from "ethers";
import { deployOrUpgrade } from "../lib/utils";

async function deployHybridModel() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  const WorkerHubScoring = await ethers.getContractFactory("WorkerHubScoring");
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
  const ModelCollection = await ethers.getContractFactory("ModelCollection");

  const collectionAddress = config.collectionAddress;
  assert.ok(
    collectionAddress,
    `Missing ${networkName}_COLLECTION_ADDRESS from environment variables!`
  );

  const workerHubScoringAddress = config.workerHubScoringAddress;
  assert.ok(
    workerHubScoringAddress,
    `Missing ${networkName}_WORKER_HUB_SCORING_ADDRESS from environment variables!`
  );

  const workerHubAddress = config.workerHubAddress;
  assert.ok(
    workerHubAddress,
    `Missing ${networkName}_WORKER_HUB_ADDRESS from environment variables!`
  );

  const modelOwnerAddress = config.l2OwnerAddress;
  assert.ok(
    modelOwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const identifier = 0;
  const name = "Scoring";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "Scoring",
    model_type: "scoring",
    model_url: "",
    model_file_hash: "",
    min_hardware: 1,
    verifier_url: "",
    verifier_file_hash: "",
  };
  const metadata = JSON.stringify(metadataObj, null, "\t");
  console.log(metadata);

  const constructorParams = [
    workerHubScoringAddress,
    collectionAddress,
    identifier,
    name,
    metadata,
  ];
  const hybridModel = (await deployOrUpgrade(
    config.hybridModelScoringAddress,
    "HybridModel",
    constructorParams,
    config,
    true
  )) as unknown as HybridModel;

  console.log(
    `Contract HybridModel has been deployed to address ${hybridModel.target}`
  );
  console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.target}`);

  if (!config.hybridModelScoringAddress) {
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

    const workerHubScoring = WorkerHubScoring.attach(
      workerHubScoringAddress
    ) as WorkerHubScoring;
    const txRegis = await workerHubScoring.registerModel(
      hybridModel.target,
      minHardware,
      ethers.parseEther("0")
    );
    const receiptRegis = await txRegis.wait();
    console.log(
      `Contract HybridModelScoring is registered to WorkerHubScoring: ${receiptRegis?.status}`
    );

    // WorkerHubScoring setupScoringVar
    const txSetup = await workerHubScoring.setupScoringVar(workerHubAddress);
    const receiptSetup = await txSetup.wait();
    console.log(
      `Contract WorkerHubScoring setup state: ${receiptSetup?.status}`
    );

    // WorkerHub setScoringInfo
    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    const txSetup2 = await workerHub.setScoringInfo(
      workerHubScoringAddress,
      hybridModel.target
    );
    const receiptSetup2 = await txSetup2.wait();
    console.log(
      `Contract WorkerHub setup Scoring Info: ${receiptSetup2?.status}`
    );
  }
}

deployHybridModel()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

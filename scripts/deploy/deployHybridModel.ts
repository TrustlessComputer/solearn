import assert from "assert";
import { version } from "chai";
import { ethers, network, upgrades } from "hardhat";
import { HybridModel, ModelCollection, WorkerHub } from "../../typechain-types";
import { EventLog, Log } from "ethers";
import { deployOrUpgrade } from "../lib/utils";

async function deployHybridModel() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  const WorkerHub = await ethers.getContractFactory("WorkerHub");
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
  const modelOwnerAddress = config.l2OwnerAddress;
  assert.ok(
    modelOwnerAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const identifier = 0;
  const name = "Eternal AI V2";
  const minHardware = 1;
  const metadataObj = {
    version: 1,
    model_name: "Hermes-3-Llama-3.1-8B",
    model_type: "text",
    model_url:
      "https://gateway.lighthouse.storage/ipfs/bafkreigdnqoe3hvlozmxnwc32qwskz3fvtuznpqzvp6o5crbnka2deczdu",
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

    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    await workerHub.registerModel(
      hybridModel.target,
      minHardware,
      ethers.parseEther("0")
    );

    console.log(`Contract HybridModel is registered to WorkerHub`);
  }

  console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.target}`);
}

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

deployHybridModel()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

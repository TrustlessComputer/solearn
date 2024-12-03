import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { HybridModel, ModelCollection, WorkerHub } from "../typechain-types";

async function updateHybridModelMetadata() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();
  const HybridModel = await ethers.getContractFactory("HybridModel");
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
    `Missing ${networkName}_WORKERHUB_ADDRESS from environment variables!`
  );
  const tokenId = 500005;
  const minHardware = BigInt(1);
  const metadataObj = {
    version: 1,
    model_name: "Hermes-3-Llama-3.1-8B",
    model: "NousResearch/Hermes-3-Llama-3.1-8B",
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

  const collection = ModelCollection.attach(
    config.collectionAddress
  ) as ModelCollection;
  await (await collection.updateTokenURI(tokenId, metadata)).wait();
  console.log("TokenURI updated");

  const modelAddress = await collection.modelAddressOf(tokenId);
  const hybridModel = HybridModel.attach(modelAddress) as HybridModel;
  await (await hybridModel.updateMetadata(metadata)).wait();
  console.log("Hybrid model metadata updated");

  const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
  const currentTier = (await workerHub.models(modelAddress)).tier;
  if (currentTier !== minHardware) {
    await (await workerHub.updateModelTier(modelAddress, minHardware)).wait();
    console.log(`Model tier updated (old=${currentTier}, new=${minHardware})`);
  }
}

updateHybridModelMetadata()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import assert from "assert";
import { ethers, network, upgrades } from "hardhat";
import { deployOrUpgrade } from "../lib/utils";
import { ModelCollection } from "../../typechain-types";

async function deployModelCollection() {
  const config = network.config as any;
  const networkName = network.name.toUpperCase();

  const treasuryAddress = config.l2OwnerAddress;
  assert.ok(
    treasuryAddress,
    `Missing ${networkName}_L2_OWNER_ADDRESS from environment variables!`
  );

  const name = "Eternal AI";
  const symbol = "";
  const mintPrice = ethers.parseEther("0");
  const royaltyReceiver = treasuryAddress;
  const royalPortion = 5_00;
  const nextModelId = 300_001; //TODO: need to change before deployment

  const constructorParams = [
    name,
    symbol,
    mintPrice,
    royaltyReceiver,
    royalPortion,
    nextModelId,
  ];

  const modelCollection = (await deployOrUpgrade(
    config.collectionAddress,
    "ModelCollection",
    constructorParams,
    config,
    true
  )) as unknown as ModelCollection;

  console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollection.target}`);
}

export async function getContractInstance(
  proxyAddress: string,
  contractName: string
) {
  const contractFact = await ethers.getContractFactory(contractName);
  const contractIns = contractFact.attach(proxyAddress);

  return contractIns;
}

deployModelCollection()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

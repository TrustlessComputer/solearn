import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, EventLog } from "ethers";
import { deployOrUpgrade } from "../lib/utils";

task("deploy:collection-erc20", "Deploy or upgrade ModelCollectionERC20 contract")
  .addParam("treasuryAddress", "Treasury address")
  .addOptionalParam("address", "Contract address to upgrade (null for new deploy)", null, types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { treasuryAddress, address } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying or upgrading ModelCollectionERC20 on ${networkName}`);

    const name = "Eternal AI"
    const symbol = ""
    const mintPrice = ethers.parseEther('0');
    const royaltyReceiver = treasuryAddress;
    const royalPortion = 5_00;
    const nextModelId = 100_001;
    
    const constructorParams = [
      name,
      symbol,
      mintPrice,
      royaltyReceiver,
      royalPortion,
      nextModelId
    ];
    
    const modelCollection = (await deployOrUpgrade(
      address, 
      "ModelCollection", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;
        
    // console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollection.target}`);
  });

task("deploy:workerhub-erc20", "Deploy hybrid contract")
  .addParam("stakeToken", "ERC20 token address")
  .addParam("treasuryAddress", "Treasury address")
  .addOptionalParam("address", "Contract address to upgrade (null for new deploy)", null, types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { treasuryAddress, address } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying or upgrading WorkerHubERC20 on ${networkName}`);

    const feePercentage = 10_00;
    const minerMinimumStake = ethers.parseEther("25000");
    const validatorMinimumStake = ethers.parseEther("40000");
    const miningTimeLimit = 10 * 60;
    const minerRequirement = 3;
    const blockPerEpoch = 600;
    const rewardPerEpochBasedOnPerf = ethers.parseEther("0");
    const rewardPerEpoch = ethers.parseEther("0");
    const unstakeDelayTime = 21 * 24 * 3600;
    const penaltyDuration = 3600;
    const finePercentage = 5_00;
    const stakeToken = "0xCDbE9D69d5d9a98D85384C05b462D16A588B53FA";
  
    const constructorParams = [
      treasuryAddress,
      feePercentage,
      minerMinimumStake,
      validatorMinimumStake,
      miningTimeLimit,
      minerRequirement,
      blockPerEpoch,
      rewardPerEpochBasedOnPerf,
      rewardPerEpoch,
      unstakeDelayTime,
      penaltyDuration,
      finePercentage,
      stakeToken,
    ];
  
    const workerHubERC20 = (await deployOrUpgrade(
      address, 
      "WorkerHubERC20", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;
  
    // console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHubERC20.target}`);
  });


task("deploy:hybrid-erc20", "Deploy HybridModelERC20 contract")
  .addParam("name", "Model name")
  .addParam("modelOwnerAddress", "Model owner address")
  .addParam("metadataJson", "Metadata in json format")
  .addParam("collectionAddress", "ModelCollectionERC20 address")
  .addParam("workerHubAddress", "WorkerHubERC20 address")
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { collectionAddress, workerHubAddress, name, modelOwnerAddress, metadataJson } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying new HybridModelERC20 on ${networkName}`);

    const identifier = 0;
    const minHardware = 1;
    const metadata = JSON.stringify(JSON.parse(metadataJson), null, "\t");
    console.log(metadata);

    const constructorParams = [
      workerHubAddress,
      identifier,
      name,
      metadata
    ];
    const hybridModelERC20 = (await deployOrUpgrade(
      null, 
      "HybridModelERC20", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;

    // console.log(`Contract HybridModelERC20 has been deployed to address ${hybridModelERC20.target}`);
    
    const collection = await ethers.getContractAt("ModelCollectionERC20", collectionAddress);
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModelERC20.target,
        0
    )).wait();

    console.log(`Contract HybridModelERC20 is minted to ModelCollectionERC20`);

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find((event: EventLog) => event.eventName === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }
    
    const workerHubERC20 = await ethers.getContractAt("WorkerHubERC20", workerHubAddress);
    await workerHubERC20.registerModel(hybridModelERC20.target, minHardware, ethers.parseEther('0.2'));

    console.log(`Contract HybridModelERC20 is registered to WorkerHubERC20`);

    // console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModelERC20.target}`);
  });

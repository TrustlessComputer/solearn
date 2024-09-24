import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, EventLog } from "ethers";
import { deployOrUpgrade } from "../lib/utilsTask";

task("deploy:collection", "Deploy or upgrade ModelCollection contract")
  .addParam("treasuryAddress", "Treasury address")
  .addOptionalParam("address", "Contract address to upgrade (null for new deploy)", "", types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { treasuryAddress, address } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying or upgrading ModelCollection on ${networkName}`);

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
      hre,
      address, 
      "ModelCollection", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;
        
    // console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollection.target}`);
  });

task("deploy:workerhub", "Deploy hybrid contract")
  .addParam("treasuryAddress", "Treasury address")
  .addOptionalParam("address", "Contract address to upgrade (null for new deploy)", null, types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { treasuryAddress, address } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying or upgrading WorkerHub on ${networkName}`);

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
  
    const workerHub = (await deployOrUpgrade(
      hre,
      address, 
      "WorkerHub", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;
  
    // console.log(`${networkName}_WORKER_HUB_ADDRESS=${workerHub.target}`);
  });


task("deploy:hybrid", "Deploy HybridModel contract")
  .addParam("name", "Model name")
  .addParam("modelOwnerAddress", "Model owner address")
  .addParam("metadataJson", "Metadata in json format")
  .addParam("collectionAddress", "ModelCollection address")
  .addParam("workerHubAddress", "WorkerHub address")
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, network } = hre;
    const { collectionAddress, workerHubAddress, name, modelOwnerAddress, metadataJson } = taskArgs
    const networkName = network.name.toUpperCase();
    console.log(`Deploying new HybridModel on ${networkName}`);

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
    const hybridModel = (await deployOrUpgrade(
      hre,
      null, 
      "HybridModel", 
      constructorParams, 
      network.config, 
      true
    ) as unknown) as ethers.Contract;

    // console.log(`Contract HybridModel has been deployed to address ${hybridModel.target}`);
    
    const collection = await ethers.getContractAt("ModelCollection", collectionAddress);
    const mintReceipt = await (await collection.mint(
        modelOwnerAddress,
        metadata,
        hybridModel.target
    )).wait();

    console.log(`Contract HybridModel is minted to ModelCollection`);

    const newTokenEvent = (mintReceipt!.logs as EventLog[]).find((event: EventLog) => event.eventName === 'NewToken');
    if (newTokenEvent) {
        console.log("tokenId:", newTokenEvent.args?.tokenId);
    }
    
    const workerHub = await ethers.getContractAt("WorkerHub", workerHubAddress);
    await workerHub.registerModel(hybridModel.target, minHardware, ethers.parseEther('0.2'));

    console.log(`Contract HybridModel is registered to WorkerHub`);

    // console.log(`${networkName}_HYBRID_MODEL_ADDRESS=${hybridModel.target}`);
  });

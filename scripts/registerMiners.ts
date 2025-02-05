import { ethers, network, upgrades } from "hardhat";
import { StakingHub, WrappedEAI } from "../typechain-types";

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
  const wEAIAddr = config.wEAIAddress;
  const wEAI = (await getContractInstance(
    wEAIAddr,
    "WrappedEAI"
  )) as WrappedEAI;

  const signers = await ethers.getSigners();

  // The order of signers is configured in hardhat.config.ts
  const signer1 = signers[1];
  const signer2 = signers[2];
  const signer3 = signers[3];
  const addrSigner1 = await signer1.getAddress();
  const addrSigner2 = await signer2.getAddress();
  const addrSigner3 = await signer3.getAddress();

  console.log(
    "Worker 1: ",
    addrSigner1,
    "Balance: ",
    await ethers.provider.getBalance(addrSigner1)
  );
  console.log(
    "Worker 2: ",
    addrSigner2,
    "Balance: ",
    await ethers.provider.getBalance(addrSigner2)
  );
  console.log(
    "Worker 3: ",
    addrSigner3,
    "Balance: ",
    await ethers.provider.getBalance(addrSigner3)
  );

  // Transfer wEAI from deployer address to workers address
  console.log("Transfer wEAI to workers");
  const txTransfer1 = await wEAI.transfer(
    addrSigner1,
    ethers.parseEther("25000")
  );
  const resTransfer1 = await txTransfer1.wait();
  console.log("hash: ", resTransfer1?.hash);
  console.log("status: ", resTransfer1?.status);

  const txTransfer2 = await wEAI.transfer(
    addrSigner2,
    ethers.parseEther("25000")
  );
  const resTransfer2 = await txTransfer2.wait();
  console.log("hash: ", resTransfer2?.hash);
  console.log("status: ", resTransfer2?.status);

  const txTransfer3 = await wEAI.transfer(
    addrSigner3,
    ethers.parseEther("25000")
  );
  const resTransfer3 = await txTransfer3.wait();
  console.log("hash: ", resTransfer3?.hash);
  console.log("status: ", resTransfer3?.status);

  // check EAI balance
  const balance1 = await wEAI.balanceOf(addrSigner1);
  const balance2 = await wEAI.balanceOf(addrSigner2);
  const balance3 = await wEAI.balanceOf(addrSigner3);
  console.log("EAI balance (worker 1): ", balance1.toString());
  console.log("EAI balance (worker 2): ", balance2.toString());
  console.log("EAI balance (worker 3): ", balance3.toString());

  // Workers approve wEAI to StakingHub
  console.log("Approve wEAI to StakingHub");
  const txApprove1 = await wEAI
    .connect(signer1)
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove1 = await txApprove1.wait();
  console.log("hash: ", resApprove1?.hash);
  console.log("status: ", resApprove1?.status);

  const txApprove2 = await wEAI
    .connect(signer2)
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove2 = await txApprove2.wait();
  console.log("hash: ", resApprove2?.hash);
  console.log("status: ", resApprove2?.status);

  const txApprove3 = await wEAI
    .connect(signer3)
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove3 = await txApprove3.wait();
  console.log("hash: ", resApprove3?.hash);
  console.log("status: ", resApprove3?.status);

  // Register miner
  const stakingHub = (await getContractInstance(
    config.stakingHubAddress,
    "StakingHub"
  )) as StakingHub;

  const modelAddress = ""; //TODO: fill the model address that you want to register
  const tier = 1;

  console.log("Register miners");
  const txRegisMiner1 = await stakingHub
    .connect(signer1)
    ["registerMiner(uint16,address)"](tier, modelAddress);
  const resRegisMiner1 = await txRegisMiner1.wait();
  console.log("hash: ", resRegisMiner1?.hash);
  console.log("status: ", resRegisMiner1?.status);

  const txRegisMiner2 = await stakingHub
    .connect(signer2)
    ["registerMiner(uint16,address)"](tier, modelAddress);
  const resRegisMiner2 = await txRegisMiner2.wait();
  console.log("hash: ", resRegisMiner2?.hash);
  console.log("status: ", resRegisMiner2?.status);

  const txRegisMiner3 = await stakingHub
    .connect(signer3)
    ["registerMiner(uint16,address)"](tier, modelAddress);
  const resRegisMiner3 = await txRegisMiner3.wait();
  console.log("hash: ", resRegisMiner3?.hash);
  console.log("status: ", resRegisMiner3?.status);

  // join mining
  console.log("Join mining");
  const txJoinMining1 = await stakingHub.connect(signer1).joinForMinting();
  const resJoinMining1 = await txJoinMining1.wait();
  console.log("hash: ", resJoinMining1?.hash);
  console.log("status: ", resJoinMining1?.status);

  const txJoinMining2 = await stakingHub.connect(signer2).joinForMinting();
  const resJoinMining2 = await txJoinMining2.wait();
  console.log("hash: ", resJoinMining2?.hash);
  console.log("status: ", resJoinMining2?.status);

  const txJoinMining3 = await stakingHub.connect(signer3).joinForMinting();
  const resJoinMining3 = await txJoinMining3.wait();
  console.log("hash: ", resJoinMining3?.hash);
  console.log("status: ", resJoinMining3?.status);

  console.log("All of miners: ", await stakingHub.getMinerAddresses());
  console.log(
    `Miners of model ${modelAddress}: `,
    await stakingHub.getMinerAddressesOfModel(modelAddress)
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

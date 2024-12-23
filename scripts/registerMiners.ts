import { ethers, network, upgrades } from "hardhat";
import { StakingHub, WorkerHub, WrappedEAI } from "../typechain-types";

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
  const admin = await signers[0].getAddress();
  const signer1 = signers[10];
  const signer2 = signers[11];
  const signer3 = signers[12];
  const addrSigner1 = signer1.address;
  const addrSigner2 = signer2.address;
  const addrSigner3 = signer3.address;

  console.log(
    "Worker 1: ",
    addrSigner1,
    "Balance worker 1: ",
    await ethers.provider.getBalance(addrSigner1)
  );
  console.log(
    "Worker 2: ",
    addrSigner2,
    "Balance worker 2: ",
    await ethers.provider.getBalance(addrSigner2)
  );
  console.log(
    "Worker 3: ",
    addrSigner3,
    "Balance worker 3: ",
    await ethers.provider.getBalance(addrSigner3)
  );

  // transfer wEAI to workers
  // console.log("Transfer wEAI to workers");
  // const txTransfer1 = await wEAI.transfer(
  //   addrSigner1,
  //   ethers.parseEther("25000")
  // );
  // const resTransfer1 = await txTransfer1.wait();
  // console.log("hash: ", resTransfer1?.hash);
  // console.log("status: ", resTransfer1?.status);

  // const txTransfer2 = await wEAI.transfer(
  //   addrSigner2,
  //   ethers.parseEther("25000")
  // );
  // const resTransfer2 = await txTransfer2.wait();
  // console.log("hash: ", resTransfer2?.hash);
  // console.log("status: ", resTransfer2?.status);

  // const txTransfer3 = await wEAI.transfer(
  //   addrSigner3,
  //   ethers.parseEther("25000")
  // );
  // const resTransfer3 = await txTransfer3.wait();
  // console.log("hash: ", resTransfer3?.hash);
  // console.log("status: ", resTransfer3?.status);

  const balance1 = await wEAI.balanceOf(addrSigner1);
  const balance2 = await wEAI.balanceOf(addrSigner2);
  const balance3 = await wEAI.balanceOf(addrSigner3);
  console.log("Balance worker 1: ", balance1.toString());
  console.log("Balance worker 2: ", balance2.toString());
  console.log("Balance worker 3: ", balance3.toString());

  // Approve
  console.log("Approve wEAI to staking hub");

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
  const modelAddr = "0x1A9C75eF8E85A5D4E98B1E35239Ba98cfad1ee93";

  console.log("Register miners");

  const txRegisMiner1 = await stakingHub
    .connect(signer1)
    ["registerMiner(uint16,address)"](1, modelAddr);
  const resRegisMiner1 = await txRegisMiner1.wait();
  console.log("hash: ", resRegisMiner1?.hash);
  console.log("status: ", resRegisMiner1?.status);

  const txRegisMiner2 = await stakingHub
    .connect(signer2)
    ["registerMiner(uint16,address)"](1, modelAddr);
  const resRegisMiner2 = await txRegisMiner2.wait();
  console.log("hash: ", resRegisMiner2?.hash);
  console.log("status: ", resRegisMiner2?.status);

  const txRegisMiner3 = await stakingHub
    .connect(signer3)
    ["registerMiner(uint16,address)"](1, modelAddr);
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

  console.log("miners: ", await stakingHub.getMinerAddresses());
  console.log(
    "miners: ",
    await stakingHub.getMinerAddressesOfModel(
      "0x1A9C75eF8E85A5D4E98B1E35239Ba98cfad1ee93"
    )
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

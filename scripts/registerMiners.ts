import { ethers, network, upgrades } from "hardhat";
import { StakingHub, WorkerHub, WrappedEAI } from "../typechain-types";
import { assert, Signer } from "ethers";

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

async function registerMiner(modelAddress: string, signers: Signer[]) {
  const wEAIAddr = config.wEAIAddress;
  const wEAI = (await getContractInstance(
    wEAIAddr,
    "WrappedEAI"
  )) as WrappedEAI;

  const oldWorkerHub = (await getContractInstance(
    "0x87e9B8630c1E20dd86451AE15aF7663D006f089c",
    "StakingHub"
  )) as StakingHub;
  const minerAddresses = await oldWorkerHub.getMinerAddressesOfModel(
    modelAddress
  );

  const admin = (await ethers.getSigners())[0];
  const addrSigner1 = await signers[0].getAddress();
  const addrSigner2 = await signers[1].getAddress();
  const addrSigner3 = await signers[2].getAddress();

  if (
    minerAddresses.length != 3 ||
    !minerAddresses.includes(addrSigner1) ||
    !minerAddresses.includes(addrSigner2) ||
    !minerAddresses.includes(addrSigner3)
  ) {
    throw new Error("Miners are not registered in the old worker hub");
  }

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

  const balance1 = await wEAI.balanceOf(addrSigner1);
  const balance2 = await wEAI.balanceOf(addrSigner2);
  const balance3 = await wEAI.balanceOf(addrSigner3);
  console.log("Balance worker 1: ", balance1.toString());
  console.log("Balance worker 2: ", balance2.toString());
  console.log("Balance worker 3: ", balance3.toString());

  // Approve
  console.log("Approve...");
  const txApprove1 = await wEAI
    .connect(signers[0])
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove1 = await txApprove1.wait();
  console.log("hash: ", resApprove1?.hash);
  console.log("status: ", resApprove1?.status);

  const txApprove2 = await wEAI
    .connect(signers[1])
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove2 = await txApprove2.wait();
  console.log("hash: ", resApprove2?.hash);
  console.log("status: ", resApprove2?.status);

  const txApprove3 = await wEAI
    .connect(signers[2])
    .approve(config.stakingHubAddress, ethers.parseEther("25000"));
  const resApprove3 = await txApprove3.wait();
  console.log("hash: ", resApprove3?.hash);
  console.log("status: ", resApprove3?.status);

  // Register miner
  const stakingHub = (await getContractInstance(
    config.stakingHubAddress,
    "StakingHub"
  )) as StakingHub;

  console.log("Register miners...");
  const txRegisMiner1 = await stakingHub
    .connect(signers[0])
    .registerMiner(modelAddress, 1);
  const resRegisMiner1 = await txRegisMiner1.wait();
  console.log("hash: ", resRegisMiner1?.hash);
  console.log("status: ", resRegisMiner1?.status);

  const txRegisMiner2 = await stakingHub
    .connect(signers[1])
    .registerMiner(modelAddress, 1);
  const resRegisMiner2 = await txRegisMiner2.wait();
  console.log("hash: ", resRegisMiner2?.hash);
  console.log("status: ", resRegisMiner2?.status);

  const txRegisMiner3 = await stakingHub
    .connect(signers[2])
    .registerMiner(modelAddress, 1);
  const resRegisMiner3 = await txRegisMiner3.wait();
  console.log("hash: ", resRegisMiner3?.hash);
  console.log("status: ", resRegisMiner3?.status);

  // join mining
  console.log("Join mining...");
  const txJoinMining1 = await stakingHub.connect(signers[0]).joinForMinting();
  const resJoinMining1 = await txJoinMining1.wait();
  console.log("hash: ", resJoinMining1?.hash);
  console.log("status: ", resJoinMining1?.status);

  const txJoinMining2 = await stakingHub.connect(signers[1]).joinForMinting();
  const resJoinMining2 = await txJoinMining2.wait();
  console.log("hash: ", resJoinMining2?.hash);
  console.log("status: ", resJoinMining2?.status);

  const txJoinMining3 = await stakingHub.connect(signers[2]).joinForMinting();
  const resJoinMining3 = await txJoinMining3.wait();
  console.log("hash: ", resJoinMining3?.hash);
  console.log("status: ", resJoinMining3?.status);

  console.log("miners: ", await stakingHub.getMinerAddresses());
  console.log(
    `miners of model ${modelAddress}: `,
    await stakingHub.getMinerAddressesOfModel(modelAddress)
  );
}

async function main() {
  const modelAddresses = config.hybridModelAddresses;
  assert(modelAddresses.length == 4, "Model addresses not equal 4");
  const signers = await ethers.getSigners();

  console.log(`Process for ${modelAddresses[0]}`);
  await registerMiner(modelAddresses[0], [signers[1], signers[2], signers[3]]);

  console.log(`Process for ${modelAddresses[1]}`);
  await registerMiner(modelAddresses[1], [signers[4], signers[5], signers[6]]);

  console.log(`Process for ${modelAddresses[2]}`);
  await registerMiner(modelAddresses[2], [signers[7], signers[8], signers[9]]);

  console.log(`Process for ${modelAddresses[3]}`);
  await registerMiner(modelAddresses[3], [
    signers[10],
    signers[11],
    signers[12],
  ]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

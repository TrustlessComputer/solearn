import { ethers, network, upgrades } from "hardhat";
import { WorkerHub, WrappedEAI } from "../typechain-types";

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
  const addrSigner1 = await signers[1].getAddress();
  const addrSigner2 = await signers[2].getAddress();
  const addrSigner3 = await signers[3].getAddress();

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

  // const tx1 = await wEAI
  //   .connect(signers[1])
  //   .wrap({ value: ethers.parseEther("25000") });
  // const res1 = await tx1.wait();
  // console.log("hash: ", res1?.hash);
  // console.log("status: ", res1?.status);

  // const tx2 = await wEAI
  //   .connect(signers[2])
  //   .wrap({ value: ethers.parseEther("25000") });
  // const res2 = await tx2.wait();
  // console.log("hash: ", res2?.hash);
  // console.log("status: ", res2?.status);

  // const tx3 = await wEAI
  //   .connect(signers[3])
  //   .wrap({ value: ethers.parseEther("25000") });
  // const res3 = await tx3.wait();
  // console.log("hash: ", res3?.hash);
  // console.log("status: ", res3?.status);

  const balance1 = await wEAI.balanceOf(addrSigner1);
  const balance2 = await wEAI.balanceOf(addrSigner2);
  const balance3 = await wEAI.balanceOf(addrSigner3);
  console.log("Balance worker 1: ", balance1.toString());
  console.log("Balance worker 2: ", balance2.toString());
  console.log("Balance worker 3: ", balance3.toString());

  // Approve
  // const txApprove1 = await wEAI
  //   .connect(signers[1])
  //   .approve(config.workerHubAddress, ethers.parseEther("25000"));
  // const resApprove1 = await txApprove1.wait();
  // console.log("hash: ", resApprove1?.hash);
  // console.log("status: ", resApprove1?.status);

  // const txApprove2 = await wEAI
  //   .connect(signers[2])
  //   .approve(config.workerHubAddress, ethers.parseEther("25000"));
  // const resApprove2 = await txApprove2.wait();
  // console.log("hash: ", resApprove2?.hash);
  // console.log("status: ", resApprove2?.status);

  // const txApprove3 = await wEAI
  //   .connect(signers[3])
  //   .approve(config.workerHubAddress, ethers.parseEther("25000"));
  // const resApprove3 = await txApprove3.wait();
  // console.log("hash: ", resApprove3?.hash);
  // console.log("status: ", resApprove3?.status);

  // Register miner
  const workerHub = (await getContractInstance(
    config.workerHubAddress,
    "WorkerHub"
  )) as WorkerHub;

  // const txRegisMiner1 = await workerHub
  //   .connect(signers[1])
  //   .registerMiner(1, ethers.parseEther("25000"));
  // const resRegisMiner1 = await txRegisMiner1.wait();
  // console.log("hash: ", resRegisMiner1?.hash);
  // console.log("status: ", resRegisMiner1?.status);

  // const txRegisMiner2 = await workerHub
  //   .connect(signers[2])
  //   .registerMiner(1, ethers.parseEther("25000"));
  // const resRegisMiner2 = await txRegisMiner2.wait();
  // console.log("hash: ", resRegisMiner2?.hash);
  // console.log("status: ", resRegisMiner2?.status);

  // const txRegisMiner3 = await workerHub
  //   .connect(signers[3])
  //   .registerMiner(1, ethers.parseEther("25000"));
  // const resRegisMiner3 = await txRegisMiner3.wait();
  // console.log("hash: ", resRegisMiner3?.hash);
  // console.log("status: ", resRegisMiner3?.status);

  // join mining
  // const txJoinMining1 = await workerHub.connect(signers[1]).joinForMinting();
  // const resJoinMining1 = await txJoinMining1.wait();
  // console.log("hash: ", resJoinMining1?.hash);
  // console.log("status: ", resJoinMining1?.status);

  // const txJoinMining2 = await workerHub.connect(signers[2]).joinForMinting();
  // const resJoinMining2 = await txJoinMining2.wait();
  // console.log("hash: ", resJoinMining2?.hash);
  // console.log("status: ", resJoinMining2?.status);

  // const txJoinMining3 = await workerHub.connect(signers[3]).joinForMinting();
  // const resJoinMining3 = await txJoinMining3.wait();
  // console.log("hash: ", resJoinMining3?.hash);
  // console.log("status: ", resJoinMining3?.status);

  console.log("miners: ", await workerHub.getMinerAddresses());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

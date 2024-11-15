import { ethers, network, upgrades } from "hardhat";
import {
  AIPoweredWallet,
  DAOToken,
  IWorkerHub,
  LLAMA,
  WorkerHub,
} from "../typechain-types";
import AIKernel from "../artifacts/contracts/AIPoweredWallet.sol/AIKernel.json";
import { Address } from "hardhat-deploy/dist/types";
import { assert } from "chai";

const config = network.config as any;

async function suspiciousTransaction() {
  const networkName = network.name.toUpperCase();
  const [receiver, sender] = await ethers.getSigners();

  const aiPoweredWalletAddress = config.aiPoweredWallet;
  assert(
    aiPoweredWalletAddress,
    `Missing ${networkName}_AI_POWERED_WALLET_ADDRESS from environment variables!`
  );

  const contractFactory = await ethers.getContractFactory("AIPoweredWallet");
  const aiPoweredWallet = contractFactory.attach(
    aiPoweredWalletAddress
  ) as AIPoweredWallet;

  const transferredAmt = ethers.parseEther("0.0001");

  console.log(
    `Check whether the transaction history is suspicious when sending ${ethers.parseUnits(
      transferredAmt.toString(),
      "ETH"
    )} ETH from ${sender.address} to ${receiver.address}...`
  );
  const txCheck = await aiPoweredWallet
    .connect(sender)
    .suspiciousTransaction(receiver.address, transferredAmt);
  const receipt = await txCheck.wait();
  // const receipt = await ethers.provider.getTransactionReceipt(
  //   "0xeb31ed383ea64e9e3e21e46a74c4bddf357700f07a58587b9f21230188115e96"
  // );
  console.log("Tx hash: ", receipt?.hash);
  console.log("Tx status: ", receipt?.status == 1 ? "Success" : "Failed");

  let inferResult;
  let inferId = 0;
  if (receipt?.status == 1) {
    // Get inference ID
    inferId = getInferId(receipt)[0];
    console.log("Inference ID: ", inferId);
    console.log("Wait for inference result...");

    // Wait for inference result
    while (true) {
      await sleep(30000);
      try {
        inferResult = await aiPoweredWallet.fetchInferenceResult(inferId);
        break;
      } catch (e: any) {
        console.log(e.message);
        continue;
      }
    }
  }

  console.log("Inference result: ", ethers.toUtf8String(inferResult));
  console.log("Send ETH after checking the transaction history...");

  const txSend = await aiPoweredWallet.connect(sender).send(inferId, {
    value: ethers.parseEther("0.0001"),
  });
  const receiptSend = await txSend.wait();
  console.log("Tx hash: ", receiptSend?.hash);
  console.log("Tx status: ", receiptSend?.status == 1 ? "Success" : "Failed");
}

export function getInferId(receipt: ethers.TransactionReceipt): number[] {
  return receipt.logs
    .filter(
      (log: any) =>
        log.topics[0] ===
          ethers.id("NewInference(uint256,address,address,uint256,uint256)") &&
        isAddressEq(log.address, config.workerHubAddress)
    )
    .map((log: any) => {
      return parseInt(log.topics[1], 16);
    });
}

function isAddressEq(a: Address, b: Address): boolean {
  return a.toLowerCase() === b.toLowerCase();
}

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

suspiciousTransaction()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

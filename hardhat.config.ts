import { HardhatUserConfig } from "hardhat/config";
import "@matterlabs/hardhat-zksync";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "dotenv/config";
import "hardhat-contract-sizer";

import "./scripts/tasks/wallet.task";
import "./scripts/tasks/control.task";

let localTestMnemonic =
  "test test test test test test test test test test test junk";
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: { optimizer: { enabled: true, runs: 200 }, viaIR: true },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: localTestMnemonic,
        accountsBalance: "10000000000000000000000000",
      },
      gas: 100_000_000,
      allowUnlimitedContractSize: true,
      blockGasLimit: 1_000_000_000_000,
    },
    localhost: {
      url: "http://localhost:8545",
      accounts: {
        mnemonic: localTestMnemonic,
        count: 10,
      },
      treasuryAddress: process.env.HARDHAT_TREASURY_ADDRESS,
      collectionAddress: process.env.HARDHAT_COLLECTION_ADDRESS,
      workerHubAddress: process.env.HARDHAT_WORKER_HUB_ADDRESS,
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      timeout: 500_000_000,
      gas: 90_000_000,
      blockGasLimit: 2_500_000_000,
    } as any,
    regtest3: {
      url: "https://eternal-ai3.tc.l2aas.com/rpc",
      accounts: [process.env.REGTEST3_PRIVATE_KEY || ""],
      treasuryAddress: process.env.REGTEST3_TREASURY_ADDRESS,
      collectionAddress: process.env.REGTEST3_COLLECTION_ADDRESS,
      workerHubAddress: process.env.REGTEST3_WORKER_HUB_ADDRESS,
      timeout: 600_000,
      gas: 90_000_000,
      gasPrice: "auto",
    } as any,
    cudatest: {
      url: "https://cuda-eternalai.testnet.l2aas.com/rpc",
      accounts: [process.env.CUDATEST_PRIVATE_KEY || ""],
      treasuryAddress: process.env.CUDATEST_TREASURY_ADDRESS,
      collectionAddress: process.env.CUDATEST_COLLECTION_ADDRESS,
      workerHubAddress: process.env.CUDATEST_WORKER_HUB_ADDRESS,
      timeout: 600_000,
      gas: 90_000_000,
      gasPrice: "auto",
    } as any,
    mainnet: {
      url: "https://node.eternalai.org/",
      chainId: 43338,
      accounts: [process.env.MAINNET_PRIVATE_KEY],
      treasuryAddress: process.env.MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.MAINNET_WORKER_HUB_ADDRESS,
      timeout: 600_000,
      gas: 90_000_000,
      gasPrice: "auto",
    } as any,
    zk_testnet: {
      url: "https://rpc.testnet.supersonic2.bvm.network/",
      ethNetwork: "sepolia",
      zksync: true,
      accounts: [process.env.ZK_TESTNET_PRIVATE_KEY],
      treasuryAddress: process.env.ZK_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ZK_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ZK_TESTNET_WORKER_HUB_ADDRESS,
      allowUnlimitedContractSize: true,
      timeout: 500_000,
      gasPrice: 1_000_000_000,
      blockGasLimit: 100_000_000_000,
    } as any,
    zk_mainnet: {
      url: "https://rpc.eternalai.bvm.network/",
      chainId: 222672,
      accounts: [process.env.ZK_MAINNET_PRIVATE_KEY],
      treasuryAddress: process.env.ZK_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ZK_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ZK_MAINNET_WORKER_HUB_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
  },
  namedAccounts: {
    deployer: 0,
  },
  paths: {
    sources: "./contracts",
    tests: "./tests",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: {
      regtest3: "abc123",
    },
    customChains: [
      {
        network: "regtest3",
        chainId: 20156,
        urls: {
          apiURL: "https://eternal-ai3.tc.l2aas.com/api",
          browserURL: "https://eternal-ai3.tc.l2aas.com",
        },
      },
    ],
  },
  mocha: {
    timeout: 2000000,
    color: true,
    reporter: "mocha-multi-reporters",
    reporterOptions: {
      configFile: "./mocha-report.json",
    },
  },
};

export default config;

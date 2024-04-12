import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import "hardhat-deploy";
import './scripts/base.task';
import './scripts/melody.task';
import './scripts/test.task';
// import "hardhat-tracer";
import "@foundry-rs/hardhat-anvil";
import 'dotenv/config'

let localTestMnemonic = "test test test test test test test test test test test junk";
const config: HardhatUserConfig = {
  defaultNetwork: "anvil",
  anvil: {
    url: "http://127.0.0.1:8545/",
    launch: false, // if set to `true`, it will spawn a new instance if the plugin is initialized, if set to `false` it expects an already running anvil instance
  },
  solidity: {
    compilers: [
      { version: "0.8.19", settings: { optimizer: { enabled: true, runs: 2000 } } },
    ]
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
    anvil: {
      url: "http://127.0.0.1:8545/",
      timeout: 600_000,
    },
    localhost: {
      url: "http://localhost:8545",
      accounts: {
        mnemonic: localTestMnemonic,
        count: 10,
      },
      timeout: 500_000_000,
      blockGasLimit: 2_500_000_000,
    },
    regtest2: {
      url: "https://eternal-ai2.tc.l2aas.com/rpc",
      accounts: [
        process.env.REGTEST2_PRIVATE_KEY || "",
      ],
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      timeout: 500_000,
      gasPrice: 1_000_000_000,
      blockGasLimit: 100_000_000_000,
    } as any,
    regtest3: {
      url: "https://eternal-ai3.tc.l2aas.com/rpc",
      accounts: [
        process.env.REGTEST3_PRIVATE_KEY || "",
      ],
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      treasuryAddress: process.env.REGTEST3_TREASURY_ADDRESS,
      collectionAddress: process.env.REGTEST3_COLLECTION_ADDRESS,
      workerHubAddress: process.env.REGTEST3_WORKER_HUB_ADDRESS,
      timeout: 500_000,
      gasPrice: 1_000_000_000,
      blockGasLimit: 100_000_000_000,
    } as any,
    cudatest: {
      url: "http://34.124.187.213:8545",
      accounts: [
        process.env.CUDATEST_PRIVATE_KEY || "",
      ],
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      treasuryAddress: process.env.CUDATEST_TREASURY_ADDRESS,
      collectionAddress: process.env.CUDATEST_COLLECTION_ADDRESS,
      workerHubAddress: process.env.CUDATEST_WORKER_HUB_ADDRESS,
      timeout: 500_000,
      gasPrice: 1_000_000_000,
      blockGasLimit: 100_000_000_000,
    } as any,
  },
  namedAccounts: {
    deployer: 0,
  },
  paths: {
    sources: './contracts',
    tests: './tests',
    cache: './cache',
    artifacts: './artifacts',
  },
  etherscan: {
    apiKey: {
      regtest3: 'abc123',
    },
    customChains: [
      {
        network: 'regtest3',
        chainId: 20156,
        urls: {
          apiURL: 'https://eternal-ai3.tc.l2aas.com/api',
          browserURL: 'https://eternal-ai3.tc.l2aas.com'
        }
      }
    ],
  },
  mocha: {
    timeout: 2000000,
    color: true,
    reporter: 'mocha-multi-reporters',
    reporterOptions: {
      configFile: './mocha-report.json',
    },
  },
};

export default config;

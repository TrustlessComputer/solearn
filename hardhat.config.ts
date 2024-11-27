import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@matterlabs/hardhat-zksync";
import "@nomiclabs/hardhat-solhint";
import "hardhat-deploy";
import "dotenv/config";
import "hardhat-contract-sizer";

import "./scripts/tasks/wallet.task";
import "./scripts/tasks/control.task";

let localTestMnemonic =
  "test test test test test test test test test test test junk";
const config: HardhatUserConfig = {
  defaultNetwork: "shard_ai_testnet",
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: { enabled: true, runs: 2000000 },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: { enabled: true, runs: 2000000 },
          viaIR: true,
          evmVersion: "paris",
        },
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
      l2OwnerAddress: process.env.HARDHAT_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.HARDHAT_TREASURY_ADDRESS,
      collectionAddress: process.env.HARDHAT_COLLECTION_ADDRESS,
      workerHubAddress: process.env.HARDHAT_WORKER_HUB_ADDRESS,
      workerHubScoringAddress: process.env.HARDHAT_WORKER_HUB_SCORING_ADDRESS,
      daoTokenAddress: process.env.HARDHAT_LLAMA_TOKEN_ADDRESS, // !NOTE: must not change
      hybridModelAddress: process.env.HARDHAT_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.HARDHAT_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.HARDHAT_SYSTEM_PROMPT_MANAGER_ADDRESS,
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
      l2OwnerAddress: process.env.ZK_TESTNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.ZK_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ZK_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ZK_TESTNET_WORKER_HUB_ADDRESS,
      workerHubScoringAddress:
        process.env.ZK_TESTNET_WORKER_HUB_SCORING_ADDRESS,
      daoTokenAddress: process.env.ZK_TESTNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.ZK_TESTNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.ZK_TESTNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.ZK_TESTNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      timeout: 500_000,
      gasPrice: 1_000_000_000,
      blockGasLimit: 100_000_000_000,
    } as any,
    llama_mainnet: {
      url: "https://rpc.eternalai.bvm.network",
      chainId: 222672,
      accounts: [process.env.LLAMA_MAINNET_PRIVATE_KEY],
      l2OwnerAddress: process.env.LLAMA_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.LLAMA_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.LLAMA_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.LLAMA_MAINNET_WORKER_HUB_ADDRESS,
      workerHubScoringAddress:
        process.env.LLAMA_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      daoTokenAddress: process.env.LLAMA_MAINNET_LLAMA_TOKEN_ADDRESS, // !NOTE: must not change
      hybridModelAddress: process.env.LLAMA_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.LLAMA_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.LLAMA_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    flux_mainnet: {
      url: "https://rpc.flux.eternalai.org",
      chainId: 222673,
      accounts: [process.env.FLUX_MAINNET_PRIVATE_KEY],
      l2OwnerAddress: process.env.FLUX_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.FLUX_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.FLUX_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.FLUX_MAINNET_WORKER_HUB_ADDRESS,
      workerHubScoringAddress:
        process.env.FLUX_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      daoTokenAddress: process.env.FLUX_MAINNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.FLUX_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.FLUX_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.FLUX_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    fans_mainnet: {
      url: "https://rpc.fans.l2aas.com",
      chainId: 45761,
      accounts: [process.env.FANS_MAINNET_PRIVATE_KEY],
      l2OwnerAddress: process.env.FANS_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.FANS_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.FANS_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.FANS_MAINNET_WORKER_HUB_ADDRESS,
      workerHubScoringAddress:
        process.env.FANS_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      daoTokenAddress: process.env.FANS_MAINNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.FANS_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.FANS_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.FANS_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    hermes_mainnet: {
      url: "https://rpc.hermeschain.eternalai.org",
      chainId: 45762,
      accounts: [process.env.HERMES_MAINNET_PRIVATE_KEY],
      l2OwnerAddress: process.env.HERMES_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.HERMES_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.HERMES_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.HERMES_MAINNET_WORKER_HUB_ADDRESS,
      daoTokenAddress: process.env.HERMES_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.HERMES_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.HERMES_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.HERMES_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.HERMES_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    base_mainnet: {
      url:
        "https://base-mainnet.infura.io/v3/" +
        process.env.BASE_MAINNET_INFURA_API_KEY,
      chainId: 8453,
      accounts: [
        process.env.BASE_MAINNET_PRIVATE_KEY,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_3,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_HERMES_1,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_HERMES_2,
        process.env.BASE_MAINNET_PRIVATE_KEY_WORKER_HERMES_3,
      ],
      l2OwnerAddress: process.env.BASE_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.BASE_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.BASE_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.BASE_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.BASE_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.BASE_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.BASE_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress_1: process.env.BASE_MAINNET_HYBRID_MODEL_ADDRESS_1,
      hybridModelAddress_2: process.env.BASE_MAINNET_HYBRID_MODEL_ADDRESS_2,
      hybridModelScoringAddress:
        process.env.BASE_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.BASE_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      systemPromptHelperAddress:
        process.env.BASE_MAINNET_SYSTEM_PROMPT_HELPER_ADDRESS,
      wEAIAddress: process.env.BASE_MAINNET_WEAI,
      aiPoweredWallet: process.env.BASE_MAINNET_AI_POWERED_WALLET_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    base_testnet: {
      url: "https://base-sepolia.blockpi.network/v1/rpc/public",
      chainId: 84532,
      accounts: [process.env.BASE_TESTNET_PRIVATE_KEY],
      l2OwnerAddress: process.env.BASE_TESTNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.BASE_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.BASE_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.BASE_TESTNET_WORKER_HUB_ADDRESS,
      daoTokenAddress: process.env.BASE_TESTNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.BASE_TESTNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.BASE_TESTNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.BASE_TESTNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.BASE_TESTNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      wEAIAddress: process.env.BASE_TESTNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    shard_ai_testnet: {
      url: "https://rpc.shard-ai.l2aas.com",
      chainId: 222671,
      accounts: [
        process.env.SHARD_AI_TESTNET_PRIVATE_KEY,
        process.env.SHARD_AI_TESTNET_PRIVATE_KEY_WORKER_1,
        process.env.SHARD_AI_TESTNET_PRIVATE_KEY_WORKER_2,
        process.env.SHARD_AI_TESTNET_PRIVATE_KEY_WORKER_3,
      ],
      proxyAdminAddress: process.env.SHARD_AI_TESTNET_PROXY_ADMIN_ADDRESS,
      l2OwnerAddress: process.env.SHARD_AI_TESTNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.SHARD_AI_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.SHARD_AI_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.SHARD_AI_TESTNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.SHARD_AI_TESTNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.SHARD_AI_TESTNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.SHARD_AI_TESTNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.SHARD_AI_TESTNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.SHARD_AI_TESTNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.SHARD_AI_TESTNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      wEAIAddress: process.env.SHARD_AI_TESTNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    tc_testnet: {
      url: "https://tc-node-auto.regtest.trustless.computer",
      chainId: 22215,
      accounts: [process.env.TC_TESTNET_PRIVATE_KEY],
      proxyAdminAddress: process.env.TC_TESTNET_PROXY_ADMIN_ADDRESS,
      l2OwnerAddress: process.env.TC_TESTNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.TC_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.TC_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.TC_TESTNET_WORKER_HUB_ADDRESS,
      daoTokenAddress: process.env.TC_TESTNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.TC_TESTNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.TC_TESTNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.TC_TESTNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.TC_TESTNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
      timeout: 2000000,
    } as any,
    ethereum_mainnet: {
      url: "https://mainnet.infura.io/v3/dfc35b256cf2420bbe4e153643b0560b",
      chainId: 1,
      accounts: [
        process.env.ETHEREUM_MAINNET_PRIVATE_KEY,
        process.env.ETHEREUM_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.ETHEREUM_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.ETHEREUM_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.ETHEREUM_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.ETHEREUM_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ETHEREUM_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ETHEREUM_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.ETHEREUM_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.ETHEREUM_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.ETHEREUM_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.ETHEREUM_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.ETHEREUM_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.ETHEREUM_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      wEAIAddress: process.env.ETHEREUM_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
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

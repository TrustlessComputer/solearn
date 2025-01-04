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
  defaultNetwork: "abstract_testnet",
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: { enabled: true, runs: 200000 },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: { enabled: true, runs: 200000 },
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
    zksync_mainnet: {
      url: "https://mainnet.era.zksync.io",

      // "https://zksync-mainnet.infura.io/v3/" +
      // process.env.ZKSYNC_MAINNET_INFURA_API_KEY,

      chainId: 324,
      accounts: [
        process.env.ZKSYNC_MAINNET_PRIVATE_KEY,
        process.env.ZKSYNC_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.ZKSYNC_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.ZKSYNC_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.ZKSYNC_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.ZKSYNC_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ZKSYNC_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ZKSYNC_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.ZKSYNC_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.ZKSYNC_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.ZKSYNC_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.ZKSYNC_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.ZKSYNC_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.ZKSYNC_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      wEAIAddress: process.env.ZKSYNC_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    arbitrum_mainnet: {
      url:
        "https://arbitrum-mainnet.infura.io/v3/" +
        process.env.ARBITRUM_MAINNET_INFURA_API_KEY,
      chainId: 42161,
      accounts: [
        process.env.ARBITRUM_MAINNET_PRIVATE_KEY,
        process.env.ARBITRUM_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.ARBITRUM_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.ARBITRUM_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.ARBITRUM_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.ARBITRUM_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ARBITRUM_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ARBITRUM_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.ARBITRUM_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.ARBITRUM_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.ARBITRUM_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.ARBITRUM_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.ARBITRUM_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.ARBITRUM_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.ARBITRUM_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.ARBITRUM_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    polygon_mainnet: {
      url:
        "https://polygon-mainnet.infura.io/v3/" +
        process.env.POLYGON_MAINNET_INFURA_API_KEY,
      chainId: 137,
      accounts: [
        process.env.POLYGON_MAINNET_PRIVATE_KEY,
        process.env.POLYGON_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.POLYGON_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.POLYGON_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.POLYGON_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.POLYGON_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.POLYGON_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.POLYGON_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.POLYGON_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.POLYGON_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.POLYGON_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.POLYGON_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.POLYGON_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.POLYGON_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.POLYGON_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.POLYGON_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    avax_mainnet: {
      url:
        "https://avalanche-mainnet.infura.io/v3/" +
        process.env.AVAX_MAINNET_INFURA_API_KEY,
      chainId: 43114,
      accounts: [
        process.env.AVAX_MAINNET_PRIVATE_KEY,
        process.env.AVAX_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.AVAX_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.AVAX_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.AVAX_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.AVAX_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.AVAX_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.AVAX_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.AVAX_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.AVAX_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.AVAX_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.AVAX_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.AVAX_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.AVAX_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.AVAX_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.AVAX_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    bsc_mainnet: {
      url: "https://bsc-dataseed1.defibit.io",
      chainId: 56,
      accounts: [
        process.env.BSC_MAINNET_PRIVATE_KEY,
        process.env.BSC_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.BSC_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.BSC_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.BSC_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.BSC_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.BSC_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.BSC_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.BSC_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.BSC_MAINNET_DAO_TOKEN_ADDRESS,
      workerHubScoringAddress:
        process.env.BSC_MAINNET_WORKER_HUB_SCORING_ADDRESS,
      hybridModelAddress: process.env.BSC_MAINNET_HYBRID_MODEL_ADDRESS,
      hybridModelScoringAddress:
        process.env.BSC_MAINNET_HYBRID_MODEL_SCORING_ADDRESS,
      systemPromptManagerAddress:
        process.env.BSC_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.BSC_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.BSC_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    ape_mainnet: {
      url: "https://apechain.drpc.org",
      chainId: 33139,
      accounts: [
        process.env.APE_MAINNET_PRIVATE_KEY,
        process.env.APE_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.APE_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.APE_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.APE_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.APE_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.APE_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.APE_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.APE_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.APE_MAINNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.APE_MAINNET_HYBRID_MODEL_ADDRESS,
      systemPromptManagerAddress:
        process.env.APE_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.APE_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.APE_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: "auto",
    } as any,
    abstract_testnet: {
      url: "https://api.testnet.abs.xyz",
      chainId: 11124,
      accounts: [
        process.env.ABSTRACT_TESTNET_PRIVATE_KEY,
        process.env.ABSTRACT_TESTNET_PRIVATE_KEY_WORKER_1,
        process.env.ABSTRACT_TESTNET_PRIVATE_KEY_WORKER_2,
        process.env.ABSTRACT_TESTNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.ABSTRACT_TESTNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.ABSTRACT_TESTNET_TREASURY_ADDRESS,
      collectionAddress: process.env.ABSTRACT_TESTNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.ABSTRACT_TESTNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.ABSTRACT_TESTNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.ABSTRACT_TESTNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.ABSTRACT_TESTNET_HYBRID_MODEL_ADDRESS,
      systemPromptManagerAddress:
        process.env.ABSTRACT_TESTNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.ABSTRACT_TESTNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.ABSTRACT_TESTNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true,
      gasPrice: "auto",
    } as any,
    subtensor_mainnet: {
      url: "https://evm-subtensor.eternalai.org",
      chainId: 964,
      accounts: [
        process.env.SUBTENSOR_MAINNET_PRIVATE_KEY,
        process.env.SUBTENSOR_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.SUBTENSOR_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.SUBTENSOR_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      proxyAdminAddress: process.env.SUBTENSOR_MAINNET_PROXY_ADMIN_ADDRESS,
      l2OwnerAddress: process.env.SUBTENSOR_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.SUBTENSOR_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.SUBTENSOR_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.SUBTENSOR_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.SUBTENSOR_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.SUBTENSOR_MAINNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.SUBTENSOR_MAINNET_HYBRID_MODEL_ADDRESS,
      systemPromptManagerAddress:
        process.env.SUBTENSOR_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      squadManagerAddress: process.env.SUBTENSOR_MAINNET_SQUAD_MANAGER_ADDRESS,
      wEAIAddress: process.env.SUBTENSOR_MAINNET_WEAI,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: false,
      gasPrice: 10000000000,
    } as any,
    duck_mainnet: {
      url: "https://rpc.duckchain.io",
      chainId: 5545,
      accounts: [
        process.env.DUCK_MAINNET_PRIVATE_KEY,
        process.env.DUCK_MAINNET_PRIVATE_KEY_WORKER_1,
        process.env.DUCK_MAINNET_PRIVATE_KEY_WORKER_2,
        process.env.DUCK_MAINNET_PRIVATE_KEY_WORKER_3,
      ],
      l2OwnerAddress: process.env.DUCK_MAINNET_L2_OWNER_ADDRESS,
      treasuryAddress: process.env.DUCK_MAINNET_TREASURY_ADDRESS,
      collectionAddress: process.env.DUCK_MAINNET_COLLECTION_ADDRESS,
      workerHubAddress: process.env.DUCK_MAINNET_WORKER_HUB_ADDRESS,
      stakingHubAddress: process.env.DUCK_MAINNET_STAKING_HUB_ADDRESS,
      daoTokenAddress: process.env.DUCK_MAINNET_DAO_TOKEN_ADDRESS,
      hybridModelAddress: process.env.DUCK_MAINNET_HYBRID_MODEL_ADDRESS,
      systemPromptManagerAddress:
        process.env.DUCK_MAINNET_SYSTEM_PROMPT_MANAGER_ADDRESS,
      wEAIAddress: process.env.DUCK_MAINNET_WEAI,
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
      arbitrumOne: "def456",
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
    timeout: 20000000,
    color: true,
    reporter: "mocha-multi-reporters",
    reporterOptions: {
      configFile: "./mocha-report.json",
    },
  },
};

export default config;

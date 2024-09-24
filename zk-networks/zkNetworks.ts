export const zk_mainnets = {
  zk_testnet: {
    url: "https://rpc.testnet.supersonic2.bvm.network",
    chainId: 22219,
    accounts: [process.env.ZK_TESTNET_PRIVATE_KEY],
    allowUnlimitedContractSize: true,
    ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
    zksync: true,
    gasPrice: "auto",
  } as any,
  zk_llama_405b: {
    url: "https://rpc.eternalai.bvm.network/",
    chainId: 222672,
    accounts: [process.env.ZK_LLAMA_405B_PRIVATE_KEY],
    treasuryAddress: process.env.ZK_LLAMA_405B_TREASURY_ADDRESS,
    collectionAddress: process.env.ZK_LLAMA_405B_COLLECTION_ADDRESS,
    workerHubAddress: process.env.ZK_LLAMA_405B_WORKER_HUB_ADDRESS,
    allowUnlimitedContractSize: true,
    ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
    zksync: true,
    gasPrice: "auto",
  } as any,
}
export const zk_mainnets = {
  zk_llama: {
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
}
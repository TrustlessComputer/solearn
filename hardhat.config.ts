import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import './scripts/base.task';
import "hardhat-tracer";

let localTestMnemonic = "test test test test test test test test test test test junk";
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      { version: "0.8.19", settings: { viaIR: true, optimizer: { enabled: true, runs: 2000 } } },
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
      blockGasLimit: 2_500_000_000,
    },
    localhost: {
      url: "http://localhost:8545",
      accounts: {
        mnemonic: localTestMnemonic,
        count: 10,
      },
      timeout: 500_000,
      blockGasLimit: 2_500_000_000,
    },
    tcbtc: {
      url: "http://localhost:10002", // your TC node
      accounts: {
        mnemonic: localTestMnemonic,
      },
      timeout: 100_000,
    },
    tctest: {
      url: "https://tc-node-auto.regtest.trustless.computer",
      accounts: {
        mnemonic: localTestMnemonic,
        count: 4,
      },
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      timeout: 500_000,
    },
    regtest: {
      url: "https://l2-node.regtest.trustless.computer",
      accounts: [
        "0x5333efdeaa7e5ab71e95775c0b1d1a15db1585f961b224625805505127248ee3", // private key
      ],
      // issue: https://github.com/NomicFoundation/hardhat/issues/3136
      // workaround: https://github.com/NomicFoundation/hardhat/issues/2672#issuecomment-1167409582
      timeout: 500_000,
      // gas: 2100000,
      // gasPrice: 8000000000,
    },
  },
  namedAccounts: {
    deployer: 0,
  },
};

export default config;
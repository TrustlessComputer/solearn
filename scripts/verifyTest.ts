import { Etherscan } from "@nomicfoundation/hardhat-verify/etherscan";
import * as hardhat from "hardhat";
import * as assert from "assert";
import fs from 'fs';

const {network} = hardhat;

async function main() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const address = "0xd9f391b2EAcac927d87908D765327b848AC175d7"
    const apiKey = "46U4UP3MRHIDJJSMBU1EAKZ3EP3UGJI3H4";
    const apiUrl = "https://eternal-ai2.tc.l2aas.com/rpc";
    const browserUrl = "https://eternal-ai2.tc.l2aas.com";

    const instance = new Etherscan(
        apiKey, // Etherscan API key
        apiUrl, // Etherscan API URL
        browserUrl // Etherscan browser URL
    );

    const content = fs.readFileSync("contracts/Test.sol");

    const sourceCode = {
        "language": "Solidity",
        "sources": {
            "contracts/Test.sol": { "content": content },
        },
        "settings": { 
            optimizer: { enabled: true, runs: 2000 } 
        },
    }
    
    if (!instance.isVerified(address)) {
      const { message: guid } = await instance.verify(
        // Contract address
        address,
        // Contract source code
        JSON.stringify(sourceCode),
        // Contract name
        "contracts/Test.sol:Test",
        // Compiler version
        "v0.8.19+commit.7dd6d404",
        // Encoded constructor arguments
        ""
      );
    
      await sleep(1000);
      const verificationStatus = await instance.getVerificationStatus(guid);
    
      if (verificationStatus.isSuccess()) {
        const contractURL = instance.getContractUrl("0x123abc...");
        console.log(
          `Successfully verified contract "MyContract" on Etherscan: ${contractURL}`
        );
      }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
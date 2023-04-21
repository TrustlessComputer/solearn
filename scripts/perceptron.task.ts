import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("mint-perceptron", "mint perceptron (without loading weights)")
  // .addOptionalParam("account", "The account's address", "")
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, deployments } = hre;
    const [ signer ] = await ethers.getSigners();

    const d = await deployments.get("Perceptrons");
    const c = await ethers.getContractAt("Perceptrons", d.address, signer);
    const tx = await c.safeMint(signer.address, "sample.uri", "first model", ["c1", "c2", "c3"]);
    console.log(tx);
  });
  
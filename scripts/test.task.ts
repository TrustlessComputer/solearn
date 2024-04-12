import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";

const ContractName = "Test";

const GasLimit = "90000000000"; // 100 B
const MaxFeePerGas = "1001000000";  // 1e-5 gwei
const MaxPriorityFeePerGas = "1000000000";
// const GasLimit = "290000000"; // 100 M
// const MaxFeePerGas = "10010";  // 1e-5 gwei
// const MaxPriorityFeePerGas = "10000";
const gasConfig = {
    gasLimit: GasLimit,
    maxPriorityFeePerGas: MaxPriorityFeePerGas,
    maxFeePerGas: MaxFeePerGas,
};

task("test-storage", "test SSTORE operation")
    .addOptionalParam("n", "number of SSTORE operation", 10000, types.int)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, upgrades } = hre;
        const [signer] = await ethers.getSigners();
        
        const Test = await ethers.getContractFactory('Test');
        const testContract = await upgrades.deployProxy(
            Test
        );
        await testContract.deployed();
        console.log(`Contract Test has been deployed to address ${testContract.address}`);
        
        for(let i = 0; i < 10; ++i) {
            {
                let startTime = new Date().getTime();
                const tx = await testContract.testSaveStorage(taskArgs.n, gasConfig);
                const rc = await tx.wait();
                let endTime = new Date().getTime();
                console.log("Save time: ", (endTime - startTime) / 1000);
                console.log(`Used gas: `, rc.gasUsed);
            }

            {
                let startTime = new Date().getTime();
                const tx = await testContract.testLoadStorage(taskArgs.n, gasConfig);
                const rc = await tx.wait();
                let endTime = new Date().getTime();
                console.log("Load time: ", (endTime - startTime) / 1000);
                console.log(`Used gas: `, rc.gasUsed);
            }
        }
        
        let startTime = new Date().getTime();
        const tx = await testContract.clearStorage(gasConfig);
        const rc = await tx.wait();
        let endTime = new Date().getTime();
        console.log("Delete time: ", (endTime - startTime) / 1000);
        console.log(`Used gas: `, rc.gasUsed);
    });


task("test-storage-multi-contract", "test SSTORE operation on multiple contract")
    .addOptionalParam("n", "number of SSTORE operation", 10000, types.int)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, upgrades } = hre;
        const [signer] = await ethers.getSigners();

        const addresses = [];        
        for(let i = 0; i < 10; ++i) {
            const Test = await ethers.getContractFactory('Test');
            const testContract = await upgrades.deployProxy(
                Test
            );
            await testContract.deployed();
            console.log(`Contract Test has been deployed to address ${testContract.address}`);
            addresses.push(testContract.address);

            {
                let startTime = new Date().getTime();
                const tx = await testContract.testSaveStorage(taskArgs.n, gasConfig);
                const rc = await tx.wait();
                let endTime = new Date().getTime();
                console.log("Save time: ", (endTime - startTime) / 1000);
                console.log(`Used gas: `, rc.gasUsed);
            }

            {
                let startTime = new Date().getTime();
                const tx = await testContract.testLoadStorage(taskArgs.n, gasConfig);
                const rc = await tx.wait();
                let endTime = new Date().getTime();
                console.log("Load time: ", (endTime - startTime) / 1000);
                console.log(`Used gas: `, rc.gasUsed);
            }
        }

        for (const addr of addresses) {
            const testContract = await ethers.getContractAt(ContractName, addr, signer);
            await testContract.clearStorage(gasConfig);
        }
    });

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    if (network.name === 'hardhat' || network.name === 'localhost') {
        await network.provider.send("evm_setIntervalMining", [3000]);
    }

    const name = "Models";
    const symbol = "MDL";
    const mintPrice = ethers.utils.parseEther('0.1');
    const royaltyReceiver = deployer;
    const royaltyPortion = 10;
    const nextModelId = 1;

    await deploy('ModelCollection', {
        from: deployer,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [name, symbol, mintPrice, royaltyReceiver, royaltyPortion, nextModelId],
                },
                // onUpgrade: {
                //     methodName: 'afterUpgrade',
                //     args: [name, symbol, mintPrice, royaltyReceiver, royaltyPortion, nextModelId],
                // }
            },
        },

        log: true,
    });

};

func.tags = ['1', 'ModelCollection'];
export default func;
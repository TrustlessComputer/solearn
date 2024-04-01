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

    // uint256 _mintPrice, uint256 _evalPrice, address _royaltyReceiver, uint256 _nextModelId
    const mintPrice = ethers.utils.parseEther('0.1');
    const evalPrice = ethers.utils.parseEther('0.01');
    const royaltyReceiver = deployer;
    const nextModelId = 1000;

    await deploy('Models', {
        from: deployer,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [mintPrice, evalPrice, royaltyReceiver],
                },
                // onUpgrade: {
                //     methodName: 'afterUpgrade',
                //     args: [mintPrice, evalPrice, royaltyReceiver, nextModelId],
                // }
            },
        },

        log: true,
    });

};

func.tags = ['1', 'Models'];
export default func;
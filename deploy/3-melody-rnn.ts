import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';

const abic = ethers.utils.defaultAbiCoder;
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy, execute } = deployments;
    const { deployer } = await getNamedAccounts();

    if (network.name === 'hardhat' || network.name === 'localhost') {
        await network.provider.send("evm_setIntervalMining", [3000]);
    }

    await deploy('MelodyRNN', {
        from: deployer,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [],
                },
                onUpgrade: {
                    methodName: 'afterUpgrade',
                    args: [],
                },
            },
        },

        log: true,
    });

};

func.tags = ['3', 'MelodyRNN'];
export default func;
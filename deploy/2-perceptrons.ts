import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';

const abic = ethers.utils.defaultAbiCoder;
const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy('Perceptrons', {
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

func.tags = ['2', 'NFT'];
export default func;
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';

const abic = ethers.utils.defaultAbiCoder;
const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, read } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy('RewardToken', {
        from: deployer,
        args: [],
        log: true,
    });
};

func.tags = ['3', 'Reward'];
export default func;

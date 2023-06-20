import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';

const abic = ethers.utils.defaultAbiCoder;
const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, read } = deployments;
    const { deployer } = await getNamedAccounts();

    const rewardToken = await deployments.get('RewardToken');
    const perceptrons = await deployments.get('Perceptrons');

    await deploy('Contests', {
        from: deployer,
        args: [perceptrons.address, rewardToken.address],
        log: true,
    });
};

func.tags = ['4', 'Contests'];
export default func;

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const modelName = 'EternalAI';
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy, get } = deployments;
    const { deployer } = await getNamedAccounts();

    const models = await get('ModelReg');
    await deploy('EternalAI', {
        from: deployer,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [modelName, models.address],
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

func.tags = ['2', modelName];
func.dependencies = ['1'];
func.skip = async () => true;
export default func;
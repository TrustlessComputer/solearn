import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';

const abic = ethers.utils.defaultAbiCoder;
const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer } = await getNamedAccounts();
    const modelParams = JSON.parse(fs.readFileSync('sample-model.json', 'utf-8'));
    const params = Object.assign({}, modelParams);
    params.layers_config = params.layers_config.config.layers.map((layer: any) => {
        let result = null;
        // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
        if (layer.class_name === 'Dense') {
            let temp = ethers.BigNumber.from(layer.config.units).toHexString();
            result = abic.encode(["uint8", "uint256"], [0, temp]);
        } else if (layer.class_name === 'Flatten') {
            result = abic.encode(["uint8"], [1]);
        } else if (layer.class_name === 'Rescaling') {
            const n1 = ethers.BigNumber.from(String(layer.config.scale * 1e18))
            const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("1000000000000000000"));
            result = abic.encode(["uint8", "int256", "int256"], [2, n1, n2]);
        }
        return result;
    }).filter((x: any) => x !== null);
    params.weights = Buffer.from(params.weight_b64, 'base64');
    params.weights = params.weights.reduce((acc: any, val: any, idx: number) => {
        if (idx % 4 === 0) {
            acc.push([]);
        }
        acc[acc.length - 1].push(val);
        return acc;
    }, []);
    params.weights = params.weights.map((b: any) => 
        ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

    await deploy('Model', {
        from: deployer,
        args: [params.model_name, params.classes_name], // weight could exeed limit, causing error during deployment
        log: true,
        // waitConfirmations: 2,
    });
    await execute('Model', {from: deployer, log: true}, 'loadWeights', params.layers_config, params.weights);
};

func.tags = ['1', 'Model'];
export default func;

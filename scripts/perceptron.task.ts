import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';

task("mint-perceptron", "mint perceptron (without loading weights)")
  .addOptionalParam("model", "model file name", "model.json", types.string)
  .addOptionalParam("contract", "contract address", "", types.string)
  .addOptionalParam("tokenid", "token id", "0", types.string)
  .addOptionalParam("uri", "token URI", "perceptrons.uri", types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, deployments } = hre;
    const [ signer ] = await ethers.getSigners();
    const abic = ethers.utils.defaultAbiCoder;

    // load params from file
    const modelParams = JSON.parse(fs.readFileSync(taskArgs.model, 'utf-8'));
    const params = Object.assign({}, modelParams);
    params.layers_config = params.layers_config.config.layers.map((layer: any) => {
        let result : String = "";
        // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
        if (layer.class_name === 'Dense') {
            let temp = ethers.BigNumber.from(layer.config.units).toHexString();
            // activation field to second byte:
            // 0 - LeakyReLU,
            // 1 - Linear,
            // 2 - ReLU,
            // 3 - Sigmoid,
            // 4 - Tanh
            let activationFn: number = 0;
            if (layer.config.activation === 'LeakyReLU') {
                activationFn = 0;
            } else if (layer.config.activation === 'Linear') {
                activationFn = 1;
            } else if (layer.config.activation === 'ReLU') {
                activationFn = 2;
            } else if (layer.config.activation === 'Sigmoid') {
                activationFn = 3;
            } else if (layer.config.activation === 'Tanh') {
                activationFn = 4;
            }

            result = abic.encode(["uint8", "uint8", "uint256"], [0, activationFn, temp]);
        } else if (layer.class_name === 'Flatten') {
            result = abic.encode(["uint8"], [1]);
        } else if (layer.class_name === 'Rescaling') {
            const n1 = ethers.BigNumber.from(String(layer.config.scale * 1e18))
            const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("1000000000000000000"));
            result = abic.encode(["uint8", "int256", "int256"], [2, n1, n2]);
        } else if (layer.class_name === 'InputLayer') {
            const w = ethers.BigNumber.from(layer.config.batch_input_shape[1])
            const h = ethers.BigNumber.from(layer.config.batch_input_shape[2])
            const c = ethers.BigNumber.from(layer.config.batch_input_shape[3])
            result = abic.encode(["uint8", "uint[3]"], [3, [w, h, c]]);
        }
    return result;
    }).filter((x: any) => x !== null);
    if (!params.weight_b64) {
        params.weights = [];
    } else {
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
    }

    let contractAddress = taskArgs.contract;
    if (contractAddress === "") {
        const Perceptrons = await deployments.get('Perceptrons');
        contractAddress = Perceptrons.address;
    }
    const c = await ethers.getContractAt("Perceptrons", contractAddress, signer);
    const tokenId = ethers.BigNumber.from(taskArgs.tokenid);
    const tx = await c.safeMint(signer.address, tokenId, taskArgs.uri, params.model_name, params.classes_name);
    await tx.wait();
    console.log("Minted perceptron");
    
    const setWeightTx = await c.setWeights(tokenId, params.layers_config, params.weights);
    await setWeightTx.wait();
    console.log("Set weights done");
  });
  
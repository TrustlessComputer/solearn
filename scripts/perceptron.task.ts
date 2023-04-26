import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';

task("mint-perceptron", "mint perceptron (and upload weights)")
  .addOptionalParam("model", "model file name", "model.json", types.string)
  .addOptionalParam("contract", "contract address", "", types.string)
  .addOptionalParam("tokenid", "token id", "0", types.string)
  .addOptionalParam("uri", "token URI", "perceptrons.uri", types.string)
  .addOptionalParam("maxlen", "max length for weights/tx", 250, types.int)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, deployments, getNamedAccounts } = hre;
    const { deployer: signerAddress } = await getNamedAccounts();
    const signer = await ethers.getSigner(signerAddress);
    const abic = ethers.utils.defaultAbiCoder;

    // load params from file
    const modelParams = JSON.parse(fs.readFileSync(taskArgs.model, 'utf-8'));
    const params = Object.assign({}, modelParams);
    
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

    let weights2 = [];
    let biases = [];

    let newLayerConfig = [];
    let input_units = 0;
    for (let i = 0; i < params.layers_config.config.layers.length; i++) {
        const layer = params.layers_config.config.layers[i];
        let result : String = "";
        // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
        if (layer.class_name === 'Dense') {
            let temp = ethers.BigNumber.from(layer.config.units).toHexString();
            const output_units = layer.config.units;
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

            // reconstruct weights
            let w = [], b = [];
            for (let i = 0; i < input_units; i++) {
                w.push(params.weights.splice(0, output_units));
            }

            weights2.push(w);
            biases.push(params.weights.splice(0, output_units));

            result = abic.encode(["uint8", "uint8", "uint256"], [0, activationFn, temp]);
            input_units = output_units;
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
            input_units = w.mul(h).mul(c).toNumber();
        }
        newLayerConfig.push(result);
    }
    params.layers_config = newLayerConfig.filter((x: any) => x !== null);

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
    
    console.log(`Set weights`);
    const truncateWeights = (_w: any[][], maxlen: number) => {
        let result = [];
        for (let i = 0; i < _w.length; i++) {
            result.push(_w[i].splice(0, maxlen));
        }
        return result;
    }
    const maxlen = taskArgs.maxlen;

    const setWeightTx = await c.setWeights(tokenId, params.layers_config, truncateWeights(weights2, maxlen), biases, -1);
    await setWeightTx.wait();
    console.log('tx', setWeightTx.hash);
    for (let wi = 0; wi < weights2.length; wi++) {        
        let currentWeights = [weights2[wi]];
        for (let temp = truncateWeights(currentWeights, maxlen); temp[0].length > 0; temp = truncateWeights(currentWeights, maxlen)) {
            const setWeightTx = await c.setWeights(tokenId, params.layers_config, temp, [], wi);
            await setWeightTx.wait();
            console.log('append layer dense #', wi, '- tx', setWeightTx.hash);
        }
    }
    console.log("Set weights done");
  });

task("eval-perceptron", "evaluate perceptron")
  .addOptionalParam("img", "image file name", "image.png", types.string)
  .addOptionalParam("contract", "contract address", "", types.string)
  .addOptionalParam("tokenid", "token id of model", "0", types.string)
  .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { ethers, deployments, getNamedAccounts } = hre;
    const { deployer: signerAddress } = await getNamedAccounts();
    const signer = await ethers.getSigner(signerAddress);

    let contractAddress = taskArgs.contract;
    if (contractAddress === "") {
        const Perceptrons = await deployments.get('Perceptrons');
        contractAddress = Perceptrons.address;
    }
    const c = await ethers.getContractAt("Perceptrons", contractAddress, signer);
    const tokenId = ethers.BigNumber.from(taskArgs.tokenid);

    const img = fs.readFileSync(taskArgs.img);
    // How to get input image size?
    const imgBuffer = await sharp(img).removeAlpha().resize(28, 28).raw().toBuffer();
    const imgArray = [...imgBuffer];
    const pixels = imgArray.map((b: any) => 
        ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));

    await c.classify(tokenId, pixels);
    });


task("get-perceptron", "get perceptron")
    .addOptionalParam("contract", "contract address", "", types.string)
    .addOptionalParam("tokenid", "token id", "0", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments } = hre;
        const [ signer ] = await ethers.getSigners();
        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const Perceptrons = await deployments.get('Perceptrons');
            contractAddress = Perceptrons.address;
        }
        const c = await ethers.getContractAt("Perceptrons", contractAddress, signer);
        const tokenId = ethers.BigNumber.from(taskArgs.tokenid);
        const perceptron = await c.getInfo(tokenId);

        fs.writeFileSync("perceptronDesc.json", JSON.stringify(perceptron));
        // console.log(JSON.stringify(perceptron));
    });
  
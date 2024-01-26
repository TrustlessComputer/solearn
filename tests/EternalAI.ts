import fs from 'fs';
import { expect } from "chai";
import sharp from 'sharp';
import { ethers, getNamedAccounts } from "hardhat";
import { BigNumber, ContractTransaction } from "ethers";

function getLayerType(name: string): number {
  // 0 - Dense
  // 1 - Flatten
  // 2 - Rescaling
  // 3 - InputLayer
  // 4 - MaxPooling2D
  // 5 - Conv2D
  let layerType: number = -1;
  if (name === 'Dense') {
    layerType = 0;
  } else if (name === 'Flatten') {
    layerType = 1;
  } else if (name === 'Rescaling') {
    layerType = 2;
  } else if (name === 'InputLayer') {
    layerType = 3;
  } else if (name === 'MaxPooling2D') {
    layerType = 4;
  } else if (name === 'Conv2D') {
    layerType = 5;
  }
  return layerType;
}

function getLayerName(type: number): string {
  // 0 - Dense
  // 1 - Flatten
  // 2 - Rescaling
  // 3 - InputLayer
  // 4 - MaxPooling2D
  // 5 - Conv2D
  let layerName: string = "N/A";
  if (type === 0) {
    layerName = 'Dense';
  } else if (type === 1) {
    layerName = 'Flatten';
  } else if (type === 2) {
    layerName = 'Rescaling';
  } else if (type === 3) {
    layerName = 'InputLayer';
  } else if (type === 4) {
    layerName = 'MaxPooling2D';
  } else if (type === 5) {
    layerName = 'Conv2D';
  }
  return layerName;
}

function getActivationType(name: string): number {
  // activation field to second byte:
  // 0 - LeakyReLU,
  // 1 - Linear,
  // 2 - ReLU,
  // 3 - Sigmoid,
  // 4 - Tanh
  let activationFn: number = -1;
  if (name === 'leakyrelu') {
    activationFn = 0;
  } else if (name === 'linear') {
    activationFn = 1;
  } else if (name === 'relu') {
    activationFn = 2;
  } else if (name === 'sigmoid') {
    activationFn = 3;
  } else if (name === 'tanh') {
    activationFn = 4;
  }
  return activationFn;
}

function getPaddingType(name: string): number {
  let paddingType: number = -1;
  if (name === "valid") {
    paddingType = 0;
  } else if (name === "same") {
    paddingType = 1;
  }
  return paddingType;
}

async function measureTime(f: any): Promise<any> {
  const start = Date.now();
  const ret = await f();
  const end = Date.now();
  console.log(`Execution time: ${(end - start) / 1000.0} s`);
  return ret
}

function pixelsToImage(pixels: BigNumber[], w: number, h: number, c: number): BigNumber[][][] {
  let ptr = 0;
  let img: BigNumber[][][] = [];
  for(let i = 0; i < w; ++i) {
    img.push([]);
    for(let j = 0; j < h; ++j) {
      img[i].push([]);
      for(let k = 0; k < c; ++k) {
        img[i][j].push(pixels[ptr]);
        ++ptr;
      }
    }
  }
  return img;
}

function getConvSize(
  w: number,
  h: number,
  f_w: number,
  f_h: number,
  s_w: number,
  s_h: number,
  padding: string,
) {
  let W = 0, H = 0, L = 0, R = 0, T = 0, B = 0;
  
  if (padding == "same") {
      W = (w + s_w - 1) / s_w;
      H = (h + s_h - 1) / s_h;
      const pad_w = (w % s_w == 0) ? Math.max(f_w - s_w, 0) : Math.max(f_w - w % s_w, 0);
      const pad_h = (h % s_h == 0) ? Math.max(f_h - s_h, 0) : Math.max(f_h - h % s_h, 0);
      L = pad_w / 2; R = pad_w - L;
      T = pad_h / 2; B = pad_h - T;
  } else if (padding = "valid") {
      W = (w - f_w) / s_w + 1;
      H = (h - f_h) / s_h + 1;
  }

  return {W, H, L, R, T, B};
}

describe("EternalAI", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function loadDeployedContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const { deployer: signerAddress } = await getNamedAccounts();
    const signer = await ethers.getSigner(signerAddress);
    const abic = ethers.utils.defaultAbiCoder;

    const ContractName = "EternalAI";
    const contractAddress = "0x639453f46C75C1b4a43a8FdBA27B03b916748a44";
    const eternalAI = await ethers.getContractAt(ContractName, contractAddress, signer);

    // load params from file
    // const modelParams = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    // const params = Object.assign({}, modelParams);

    // let weightsFlat: BigNumber[] = [];
    // if (params.weight_b64) {
    //   const temp = Buffer.from(params.weight_b64, 'base64');
    //   const floats = new Float32Array(new Uint8Array(temp).buffer);
    //   for (let i = 0; i < floats.length; i++) {
    //     weightsFlat.push(BigNumber.from(String(Math.trunc(floats[i] * 1e18))));
    //   }
    // }

    // let weightsDense: BigNumber[][] = [];
    // let weightsConv2D: BigNumber[][] = [];
    // let totDenseSize = 0;
    // let totConv2DSize = 0;

    // let newLayerConfig = [];
    // let input_units: any = 0;
    // for (let i = 0; i < params.layers_config.config.layers.length; i++) {
    //     const layer = params.layers_config.config.layers[i];
    //     let result: String = "";
    //     // class_name field to first byte: 0 = Dense, 1 = Flatten, 2 = Rescaling
    //     if (layer.class_name === 'Dense') {
    //         let temp = BigNumber.from(layer.config.units).toHexString();
    //         const output_units = layer.config.units;

    //         let activationFn: number = getActivationType(layer.config.activation);

    //         // reconstruct weights
    //         let layerWeights = weightsFlat.splice(0, input_units * output_units + output_units)
    //         weightsDense.push(layerWeights);
    //         totDenseSize += layerWeights.length;

    //         result = abieternalAI.encode(["uint8", "uint8", "uint256"], [0, activationFn, temp]);
    //         input_units = output_units;
    //     } else if (layer.class_name === 'Flatten') {
    //         result = abieternalAI.encode(["uint8"], [1]);
    //         input_units = input_units[0] * input_units[1] * input_units[2];
    //     } else if (layer.class_name === 'Rescaling') {
    //         const n1 = BigNumber.from(String(layer.config.scale * 1e18))
    //         const n2 = BigNumber.from(layer.config.offset).mul(BigNumber.from("1000000000000000000"));
    //         result = abieternalAI.encode(["uint8", "int256", "int256"], [2, n1, n2]);
    //     } else if (layer.class_name === 'InputLayer') {
    //         const w = BigNumber.from(layer.config.batch_input_shape[1])
    //         const h = BigNumber.from(layer.config.batch_input_shape[2])
    //         const c = BigNumber.from(layer.config.batch_input_shape[3])
    //         result = abieternalAI.encode(["uint8", "uint[3]"], [3, [w, h, c]]);
    //         input_units = [w.toNumber(), h.toNumber(), eternalAI.toNumber()];
    //     } else if (layer.class_name === 'MaxPooling2D') {
    //         const f_w = layer.config.pool_size[0];
    //         const f_h = layer.config.pool_size[1]; 
    //         const s_w = layer.config.strides[0];
    //         const s_h = layer.config.strides[1];
    //         const padding = layer.config.padding;

    //         result = abieternalAI.encode(["uint8", "uint[2]", "uint[2]", "uint8"], [
    //             4, 
    //             [BigNumber.from(f_w), BigNumber.from(f_h)], 
    //             [BigNumber.from(s_w), BigNumber.from(s_h)],
    //             getPaddingType(padding),
    //         ]);

    //         const {W, H} = getConvSize(input_units[0], input_units[1], f_w, f_h, s_w, s_h, padding);
    //         input_units = [W, H, input_units[2]];
    //     } else if (layer.class_name === 'Conv2D') {
    //         const filters = layer.config.filters;
    //         const f_w = layer.config.kernel_size[0];
    //         const f_h = layer.config.kernel_size[1]; 
    //         const s_w = layer.config.strides[0];
    //         const s_h = layer.config.strides[1];
    //         const padding = layer.config.padding;
    //         const d = input_units[2];

    //         let activationFn: number = getActivationType(layer.config.activation);

    //         // reconstruct weights
    //         // Filter: (F_W, F_H, D, K)
    //         let layerWeights = weightsFlat.splice(0, f_w * f_h * d * filters + filters)
    //         weightsConv2D.push(layerWeights);
    //         totConv2DSize += layerWeights.length;

    //         result = abieternalAI.encode(["uint8", "uint8", "uint", "uint[2]", "uint[2]", "uint8"], [
    //             5,
    //             activationFn,
    //             BigNumber.from(filters),
    //             [BigNumber.from(f_w), BigNumber.from(f_h)],
    //             [BigNumber.from(s_w), BigNumber.from(s_h)],
    //             getPaddingType(padding),
    //         ]);

    //         const {W, H} = getConvSize(input_units[0], input_units[1], f_w, f_h, s_w, s_h, padding);
    //         input_units = [W, H, filters];
    //     } 
    //     newLayerConfig.push(result);
    // }
    // params.layers_config = newLayerConfig.filter((x: any) => x !== null);

    // const tokenId = "0";
    // const uri = "";
    // const maxlen = 500;
    // try {
    //   const tx = await eternalAI.safeMint(signer.address, tokenId, uri, params.model_name, params.classes_name, { value: ethers.utils.parseEther("0.01") });
    //   await tx.wait();
    //   console.log("Minted new EternalAI model");
    // } catch (e) {
    //   const ownerAddress = await eternalAI.ownerOf(tokenId).catch(_ => {
    //     throw e;
    //   });
    //   if (ethers.utils.getAddress(ownerAddress) === ethers.utils.getAddress(signer.address)) {
    //     console.log("Using existing EternalAI model #" + tokenId.toString());
    //   } else {
    //     console.log("EternalAI #" + tokenId.toString(), "already exists and belongs to", ownerAddress);
    //     return;
    //   }
    // }

    // console.log("Weight dense size: ", totDenseSize);
    // console.log("Weight conv2d size: ", totConv2DSize);

    // console.log(`Set weights`);
    // const truncateWeights = (_w: BigNumber[], maxlen: number) => {
    //     return _w.splice(0, maxlen);
    // }

    // const weightStr = JSON.stringify([weightsDense, weightsConv2D]);
    // console.log("Total weights len: ", weightStr.length);

    // const setWeightTx = await eternalAI.setEternalAI(tokenId, params.layers_config);
    // await setWeightTx.wait();
    // console.log('tx', setWeightTx.hash);

    // const layerInfos = [];
    // for (let wi = 0; wi < weightsDense.length; wi++) {
    //     let currentWeights = weightsDense[wi];
    //     for (let temp = truncateWeights(currentWeights, maxlen); temp.length > 0; temp = truncateWeights(currentWeights, maxlen)) {
    //         console.log(temp.length);
    //         const setWeightTx = await eternalAI.appendWeights(tokenId, temp, wi, 0);
    //         await setWeightTx.wait(2);
    //         console.log('append layer dense #', wi, '- tx', setWeightTx.hash);
    //     }
    //     const layerInfo = await eternalAI.getDenseLayer(tokenId, wi);
    //     layerInfos.push(layerInfo);
    // }
    // for (let wi = 0; wi < weightsConv2D.length; wi++) {
    //     let currentWeights = weightsConv2D[wi];
    //     for (let temp = truncateWeights(currentWeights, maxlen); temp.length > 0; temp = truncateWeights(currentWeights, maxlen)) {
    //         console.log(temp.length);
    //         const setWeightTx = await eternalAI.appendWeights(tokenId, temp, wi, 5);
    //         await setWeightTx.wait(2);
    //         console.log('append layer conv2D #', wi, '- tx', setWeightTx.hash);
    //     }
    //     const layerInfo = await eternalAI.getConv2DLayer(tokenId, wi);
    //     layerInfos.push(layerInfo);
    // }

    // fs.writeFileSync("tmp_model.json", JSON.stringify(layerInfos));
    // console.log("Set weights done");

    return { eternalAI, owner: signerAddress, abic };
  }

  describe("Debug", function () {
    it("debug maxPooling2D", async function () {
      const { eternalAI, owner, abic } = await loadDeployedContract();

      const tokenId = BigNumber.from("2");
      const imgPath = "sample-images/10x10/cryptoadz/000.png"
      // const imgPath = "sample-images/cifar10/airplane/0000.jpg"
      const offline = false;

      const imgRaw = fs.readFileSync(imgPath);
      console.log("img: ", imgRaw);

      // console.log(eternalAI.address);
      // console.log(await ethers.provider.getCode(eternalAI.address));

      // How to get input image size?
      const img = sharp(imgRaw);
      const metadata = await img.metadata(); 
      const w = metadata.width;
      const h = metadata.height;
      const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
      const imgArray = [...imgBuffer];
      const pixels = imgArray.map((b: any) =>
          BigNumber.from(b).mul(BigNumber.from(10).pow(BigNumber.from(18))));

      const model = await eternalAI.getInfo(tokenId);
      let numLayers = model[3].length;
      let batchLayerNum = 1;
      let inputs = pixels;
      let dim: [BigNumber, BigNumber, BigNumber] = [BigNumber.from(w), BigNumber.from(h), BigNumber.from(3)];
      let x1: BigNumber[][][] = pixelsToImage(pixels, w, h, 3);
      let x2: BigNumber[] = [];
      let classsNameRes = "";

      // console.log("classsNameRes: ", classsNameRes);

      // await measureTime(async () => {
      //     return await eternalAI.testAdd(BigNumber.from(10800));
      // });

      // await measureTime(async () => {
      //     return await eternalAI.testMul(BigNumber.from(10800));
      // });

      // await measureTime(async () => {
      //     return await eternalAI.testAddInt256(BigNumber.from(10800));
      // });

      // await measureTime(async () => {
      //     return await eternalAI.testForLoop(BigNumber.from(10800));
      // });

      if (offline) {
          for (let i = 0; ; i = i + batchLayerNum) {
              const fromLayerIndex = i;
              const toLayerIndex = i + batchLayerNum - 1;

              const [className, r1, r2] = await eternalAI.evaluate(tokenId, fromLayerIndex, toLayerIndex, x1, x2);
              console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
              if (x1.length > 0) {
                  console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length})`);
                  fs.writeFileSync(`x1_${i}.json`, JSON.stringify(x1));
              }
              if (x2.length > 0) {
                  console.log(`x2: (${x2.length})`);
                  fs.writeFileSync(`x2_${i}.json`, JSON.stringify(x2));
              }

              // const [className, r1, r2] = await measureTime(async () => {
              //     return await eternalAI.evaluate(tokenId, fromLayerIndex, toLayerIndex, x1, x2);
              // });
              x1 = r1;
              x2 = r2;
              classsNameRes = className;

              if (className != "") {
                  console.log("result: ", className);
              }

              // console.log("result:", output, className);

              if (toLayerIndex >= numLayers - 1) {
                  break;
              }
          }    
      } else {
          // const evPromise = eternalAI.once('Classified', (tokenId, classIndex, className, outputs) => {
          //     console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs });
          //     classsNameRes = className;
          // });

          for (let i = 0; ; i = i + batchLayerNum) {
              const fromLayerIndex = i;
              const toLayerIndex = i + batchLayerNum - 1;
              // const evPromise2 = eternalAI.once('Forwarded', (tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2) => {
                  // console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2 });
                  // x1 = outputs1;
                  // x2 = outputs2;
              // });

              // console.log(`Layer ${i}: ${getLayerName(model[3][i][0])}`)
              // if (x1.length > 0) {
              //     console.log(`x1: (${x1.length}, ${x1[0].length}, ${x1[0][0].length}, ${x1[0][0][0].length})`);
              // }
              // if (x2.length > 0) {
              //     console.log(`x2: (${x2.length}, ${x2[0].length})`);
              // }

              const tx: ContractTransaction = await measureTime(async () => {
                  return await eternalAI.classify(tokenId, fromLayerIndex, toLayerIndex, x1, x2, { value: ethers.utils.parseEther("0.0001") });
              });

              console.log(`Layer index: ${fromLayerIndex} => ${toLayerIndex}: Tx: ${tx.hash}`);
              const receipt = await tx.wait(5);

              const forwardedEvent = receipt.events?.find(event => event.event === 'Forwarded');
              const classifiedEvent = receipt.events?.find(event => event.event === 'Classified');
              if (forwardedEvent) {
                  const tokenId = forwardedEvent.args?.tokenId;
                  const fromLayerIndex = forwardedEvent.args?.fromLayerIndex;
                  const toLayerIndex = forwardedEvent.args?.toLayerIndex;
                  const outputs1 = forwardedEvent.args?.outputs1;
                  const outputs2 = forwardedEvent.args?.outputs2;
                  console.log('"Forwarded" event emitted', { tokenId, fromLayerIndex, toLayerIndex, outputs1, outputs2 });
                  x1 = outputs1;
                  x2 = outputs2;
              } else if (classifiedEvent) {
                  const tokenId = classifiedEvent.args?.tokenId;
                  const classIndex = classifiedEvent.args?.classIndex;
                  const className = classifiedEvent.args?.className;
                  const outputs = classifiedEvent.args?.outputs;
                  console.log('"Classified" event emitted', { tokenId, classIndex, className, outputs });
                  classsNameRes = className;
              }

              if (toLayerIndex >= numLayers - 1) {
                  break;
              }
          }
      }
    });
  });
});

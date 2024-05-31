import { ethers } from "hardhat";
import fs from 'fs';
import sharp from 'sharp';
import { ImageClassifier, loadModel } from "./models/Sequential";
import { Tensor3D } from "./tensors/Tensor3D";
import { Tensor1D } from "./tensors/Tensor1D";

export function pixelsToImage(pixels: number[], h: number, w: number, c: number): number[][][] {
  let ptr = 0;
  let img: number[][][] = [];
  for(let i = 0; i < h; ++i) {
    img.push([]);
    for(let j = 0; j < w; ++j) {
      img[i].push([]);
      for(let k = 0; k < c; ++k) {
        img[i][j].push(pixels[ptr]);
        ++ptr;
      }
    }
  }
  return img;
}

async function main() {
  const modelPath = 'sample-models/nft_mlp_10x10.json';
  const imgPath = 'sample-images/nft/cryptoadz/000.png';

  const modelJson = fs.readFileSync(modelPath).toString();
  const modelObj = JSON.parse(modelJson);

  const layersConfig = modelObj.layers_config;
  const weight_b64 = modelObj.weight_b64;
  const classesName = modelObj.classes_name;
  
  const { model, inputDim } = loadModel(layersConfig, weight_b64, ImageClassifier);

  const imgRaw = fs.readFileSync(imgPath);
  console.log("imgRaw: ", imgRaw);

  const h = inputDim[0];
  const w = inputDim[1];

  const img = sharp(imgRaw);
  const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
  const imgArray = [...imgBuffer];
  const pixels = pixelsToImage(imgArray, h, w, 3);

  const pixelsTensor = new Tensor3D(pixels)

  const logits = model.forward(pixelsTensor);
  const probs = Tensor1D.softmax(logits).mat;

  const prediction = probs.indexOf(Math.max(...probs))
  console.log(classesName[prediction], probs[prediction]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

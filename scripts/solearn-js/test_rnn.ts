import fs from 'fs';
import { TextGenerator, loadModel } from "./models/Sequential";
import { Tensor1D } from "./tensors/Tensor1D";
import { RandomUtils } from './utils/random';

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
  const modelPath = 'sample-models/shakespeare_simplernn.json';

  const modelJson = fs.readFileSync(modelPath).toString();
  const modelObj = JSON.parse(modelJson);

  const layersConfig = modelObj.layers_config;
  const weight_b64 = modelObj.weight_b64;
  const vocab = modelObj.vocabulary;
  
  const { model, inputDim } = loadModel(layersConfig, weight_b64, TextGenerator);

  const seed = '123';
  const outputLength = 1000;
  const rnd = new RandomUtils(seed);

  const prompts = ['ROMEO:'];
  for (const prompt of prompts) {
    let logits_tensor = Tensor1D.load([], vocab.length);
    for(let i = 0; i < prompt.length; ++i) {
      const id = vocab.indexOf(prompt[i]);
      logits_tensor = model.forward(id);
    }

    let result = prompt;
    for(let i = 0; i < outputLength; ++i) {
      logits_tensor.mat[0] = -Infinity;
      const prob_tensor = Tensor1D.softmax(logits_tensor);
      const items = prob_tensor.mat.map((item, idx) => [idx, item]);
      const predicted_id = rnd.getRandomItem(items);
      logits_tensor = model.forward(predicted_id);
      result += vocab[predicted_id];
    }

    console.log(result);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

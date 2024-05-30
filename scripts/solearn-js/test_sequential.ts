import { ethers } from "hardhat";
import fs from 'fs';
import { loadModel } from "./models/Sequential";

async function main() {
    const modelPath = 'sample-models/nft_mlp_10x10.json';
    const imgPath = 'sample-images/nft/cryptoadz/000.png';

    const modelJson = fs.readFileSync(modelPath).toString();
    const modelObj = JSON.parse(modelJson);

    const model = loadModel()

    const layersConfig = modelObj.layers_config;
    const weights_b64 = modelObj.weights_b64;
    
    const imgRaw = fs.readFileSync(imgPath);
    console.log("imgRaw: ", imgRaw);
    // TODO: Get inputDim from TextRNN and use the width and height from inputDim instead
    // How to get input image size?

    const model = await implementContract.getInfo();
    const inputDim = model[0];
    if (inputDim.length < 2) {
        throw new Error("Invalid model input dim");
    }
    const h = inputDim[0].toNumber();
    const w = inputDim[1].toNumber();

    const img = sharp(imgRaw);
    const imgBuffer = await img.removeAlpha().resize(w, h).raw().toBuffer();
    const imgArray = [...imgBuffer];
    const pixelsFlat = imgArray.map((b: any) => fromInt(b));
    const pixels: ethers.BigNumber[][][] = pixelsToImage(pixelsFlat, h, w, 3);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

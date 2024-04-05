import fs from 'fs';
import { ethers, utils } from "ethers";
import path from 'path';
import levenshtein from 'js-levenshtein';

export function recursiveToString(arr: any): any {
  return arr.map((val: any) => Array.isArray(val) ? recursiveToString(val) : val.toString());
}

export function getLayerType(name: string): number {
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
  } else if (name === 'Embedding') {
      layerType = 6;
  } else if (name === 'SimpleRNN') {
      layerType = 7;
  } else if (name === 'LSTM') {
      layerType = 8;
  }
  return layerType;
}

export function getLayerName(type: number): string {
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
  } else if (type === 6) {
      layerName = 'Embedding';
  } else if (type === 7) {
      layerName = 'SimpleRNN';
  } else if (type === 8) {
      layerName = 'LSTM';
  }
  return layerName;
}

export function getActivationType(name: string): number {
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

export function getPaddingType(name: string): number {
  let paddingType: number = -1;
  if (name === "valid") {
      paddingType = 0;
  } else if (name === "same") {
      paddingType = 1;
  }
  return paddingType;
}

export async function measureTime(f: any): Promise<any> {
  const start = Date.now();
  const ret = await f();
  const end = Date.now();
  console.log(`Execution time: ${(end - start) / 1000.0} s`);
  return ret
}

export function pixelsToImage(pixels: ethers.BigNumber[], h: number, w: number, c: number): ethers.BigNumber[][][] {
  let ptr = 0;
  let img: ethers.BigNumber[][][] = [];
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

export function getConvSize(
  dim: number[],
  size: number[],
  stride: number[],
  padding: string,
): { 
  out: number[], 
  pad: number[] 
} {
  const out = [], pad = [];
  for(let i = 0; i < 2; ++i) {
      if (padding == "same") {
          out.push((dim[i] + stride[i] - 1) / stride[i]);
          const total_pad = (dim[i] % stride[i] == 0) ? Math.max(size[i] - stride[i], 0) : Math.max(size[i] - dim[i] % stride[i], 0);
          pad.push(total_pad / 2);
      } else if (padding == "valid") {
          // TODO: What if dim[i] < size[i]
          out.push((dim[i] - size[i]) / stride[i] + 1);
          pad.push(0);
      }
  }
  return { out, pad };
}

export async function getModelDirents(folder: string): Promise<fs.Dirent[]> {
  const dirs = await fs.promises.readdir(folder, { withFileTypes: true });
  return dirs.filter(dirent => dirent.isFile() && path.extname(dirent.name) == ".json");
}

export function fuzzyMatch(word: string, dict: string[]): string {
  let bestCand = "", bestDist = -1;
  for(let cand of dict) {
      const dist = levenshtein(word, cand);
      if (bestCand === "" || dist < bestDist) {
          bestCand = cand;
          bestDist = dist;
      }
  }
  return bestCand;
}

export function tokenizeWordOnly(text: string): string[] {
  const tokens: string[] = [];
  let word = "";
  for(let c of text) {
      if (c === '\'' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
          word += c;
      } else {
          if (word !== "") {
              tokens.push(word);
              word = "";
          }
      }
  }
  return tokens;
}

export function replaceMatchedWords(text: string, words: string[], matchedWords: string[]): string {
  let result = "";
  for(let i = 0; i < words.length; ++i) {
      let pos = text.search(words[i]);
      result += text.substring(0, pos) + matchedWords[i];
      text = text.slice(pos + words[i].length);
  }
  return result;
}

export function postprocessText(text: string, dict: string[]): string {
  const words = tokenizeWordOnly(text);
  const matchedWords = words.map(word => fuzzyMatch(word, dict));
  const replacedText = replaceMatchedWords(text, words, matchedWords);
  return replacedText;
}

export function fromFloat(num: any) {
  return ethers.BigNumber.from(String(Math.trunc(num * Math.pow(2, 32))));
}

export function fromInt(num: any) {
  return ethers.BigNumber.from(num).mul(ethers.BigNumber.from(2).pow(ethers.BigNumber.from(32)));
}

export function toInt(num: any) {
  return ethers.BigNumber.from(num).div(ethers.BigNumber.from(2).pow(ethers.BigNumber.from(32)));
}

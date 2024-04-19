import fs from 'fs';
import { ethers, utils } from "ethers";
import path from 'path';
import levenshtein from 'js-levenshtein';

export function recursiveToString(arr: any): any {
    return arr.map((val: any) => Array.isArray(val) ? recursiveToString(val) : val.toString());
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

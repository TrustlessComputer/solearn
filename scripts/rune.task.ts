import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { open, writeFile } from "fs/promises";

const InscriptionType = {
    PRE_NORSE: 0,
    VIKING: 1,
    MEDIEVAL: 2,
}

var medievalArray = [
    { rune: 'ᛆ',letters: ['a', 'ä'] },
    { rune: 'ᛒ',letters: ['b'] },
    { rune: 'ᛌ',letters: ['c'] },
    { rune: 'ᛑ',letters: ['d'] },
    { rune: 'ᚦ',letters: ['th', 'þ'] },
    { rune: 'ᚧ',letters: ['ð'] },    
    { rune: 'ᛂ',letters: ['e'] },
    { rune: 'ᚠ',letters: ['f'] },
    { rune: 'ᚵ',letters: ['g'] },
    { rune: 'ᛡ',letters: ['h'] },
    { rune: 'ᛁ',letters: ['i', 'j'] },
    { rune: 'ᚴ',letters: ['k', 'q'] },
    { rune: 'ᛚ',letters: ['l'] },
    { rune: 'ᛉ',letters: ['m'] },
    { rune: 'ᚿ',letters: ['n'] },
    { rune: 'ᚮ',letters: ['o', 'ö', 'õ'] },
    { rune: 'ᛔ',letters: ['p'] },
    { rune: 'ᚱ',letters: ['r'] },
    { rune: 'ᛍ',letters: ['s'] },
    { rune: 'ᛐ',letters: ['t'] },
    { rune: 'ᚢ',letters: ['u'] },
    { rune: 'ᚡ',letters: ['v', 'w'] },
    { rune: 'ᚤ',letters: ['y', 'ü'] },
    { rune: 'ᛅ',letters: ['æ'] },
    { rune: 'ᚯ',letters: ['ø'] },
    { rune: 'ᛜ',letters: ['ng', 'ŋ'] },
    { rune: 'ᛪ',letters: ['z'] },    
    
    { rune: '×', letters: ['\'', ':']},
    { rune: 'ᚴᛍ', letters: ['x'] },
    { rune: '·', letters: [' ']},
];
        
function medievalTextToRune(inputText: string): string {
    let inputArray = replaceSpelling(inputText).split('');
    let medieval = "";

    let isLatin = false;
    for(var i = 0; i < inputArray.length; i++)
    {
      	var letter = inputArray[i].toLowerCase();
        if (letter === "{") {
            isLatin = true;
        } else if (letter === "}") {
            isLatin = false;
        } else {
            if (isLatin) {
                // medieval += letter;
            } else {
                medieval += getRunes(letter, medievalArray);
            }
        }
    }

    medieval = medieval.trim();
    medieval = medieval.replace(/\s+/g, '·');
    return medieval;
};

function getRunes(letter: any, array: any) {
    try{
  		return array.filter(a => a.letters.some(b => b == letter))[0].rune;
    }
    catch(e){
        if (letter === ' ') return ' ';
        if (letter !== 'ʀ') console.log(letter);
        return '';
    }
}
  
function replaceSpelling(input: string) {
    input = input.replace(/th/g, 'þ');
    input = input.replace(/x/g, 'ks');
    input = input.replace(/ae/g, 'æ');
    input = input.replace(/ia/g, 'õ');
    input = input.replace(/io/g, 'ö');
    input = input.replace(/ea/g, 'ä');
    //input = input.replace(/r /g, 'ʀ ');
    input = input.replace(/ng/g, 'ŋ');
    var lastChar = input[input.length - 1];
    if(lastChar === 'r') input = input.replace(/.$/,"ʀ");
    
  	return input;
}

export function isRune(data: string): boolean {
    for (const c of data) {
        if (medievalArray.filter(a => a.rune === c).length === 0) {
            return false;
        }
    }
    return true;
}

export function runeToText(inputRune: string): string {
    var translatedText = "";
    
    for(var i = 0; i < inputRune.length; i++){
        var letter = inputRune[i];
        var match = medievalArray.filter(a => a.rune == inputRune[i])[0];
        if(match != null) letter = match.letters[0];
        if (letter === '·') letter = ' ';
        
        translatedText += letter;
    }

    return translatedText;
}

function getInscriptionType(data: string) {
    if (data.includes("M")) {
        return InscriptionType.MEDIEVAL;
    } else if (data.includes("U")) {
        return InscriptionType.PRE_NORSE;
    } else {
        return InscriptionType.VIKING;
    }
}

async function readEntries(filePath: string) {
    const file = await open(filePath);

    const entries = [];    
    for await (const line of file.readLines()) {
        if (line.startsWith("!")) continue;
        const tokens = line.split(' ');
        
        const type = getInscriptionType(tokens[2]);
        const text = tokens.slice(3).join(' ');

        entries.push({
            type,
            text,
        });
    }

    return entries;
}

function preprocessText(text: string) {
    if (text.includes('°')) return '';

    const tokens = text.split(' ');
    const filteredTokens = tokens.filter((token: string) => {
        if (token === '') return false;
        if (token.includes('.') || token.includes('-') || token.includes('?')) return false;
        if (token.includes('—')) return false;
        if (token.startsWith('§')) return false;
        return true;
    }).map((token: string) => {
        if (token.includes('/')) {
            token = token.split('/')[0];
        }
        token = token.replace(/ô/g, 'ø');
        return token;
    });
    return filteredTokens.join(' ');
}

async function processEntries(entries: any[]) {
    const result = [];
    for(const { type, text } of entries) {
        if (type !== InscriptionType.MEDIEVAL) continue;
        const processedText = preprocessText(text);
        // if (processedText.includes('§')) {
        //     console.log(text);
        //     console.log(processedText);
        // }
        const rune = medievalTextToRune(processedText);
        if (rune === "") continue;
        result.push(rune);

        // console.log(text);
        // console.log(rune);
    }
    return result;
}

task("text-to-rune", "translate text to rune")
    .addOptionalParam("text", "text to translate", "Hello World", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const rune = medievalTextToRune(taskArgs.text);
        console.log(rune);

        const recoveredText = runeToText(rune);
        console.log(recoveredText);
    });

task("rune-to-text", "translate rune to text")
    .addOptionalParam("rune", "rune to translate", "ᛡᛂᛚᛚᚮ·ᚡᚮᚱᛚᛑ", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const recoveredText = runeToText(taskArgs.rune);
        console.log(recoveredText);
    });  

task("parse-dataset", "parse runtext dataset")
    .addOptionalParam("filepath", "file path", "", types.string)
    .addOptionalParam("outputpath", "output path", "output.txt", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const entries = await readEntries(taskArgs.filepath);

        const medievalRunes = await processEntries(entries);
        // console.log(medievalRunes);

        await writeFile(taskArgs.outputpath, medievalRunes.join('·'));
    });

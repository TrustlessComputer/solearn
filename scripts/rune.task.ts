import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { open, writeFile } from "fs/promises";

const InscriptionType = {
    PRE_NORSE: 0,
    VIKING: 1,
    MEDIEVAL: 2,
}

var elderArray = [
    { rune: 'ᚠ', letters: ['f']  },
    { rune: 'ᚢ', letters: ['u', 'ø', 'ü', 'v']  },
    { rune: 'ᚦ', letters: ['þ', 'ð']  },
    { rune: 'ᚨ', letters: ['a'] },
    { rune: 'ᚱ', letters: ['r', 'ʀ']  },
    { rune: 'ᚲ', letters: ['k', 'c', 'q']  },
    { rune: 'ᚷ', letters: ['g']  },
    { rune: 'ᚹ', letters: ['w']},
    { rune: 'ᚺ', letters: ['h']  },
    { rune: 'ᚾ', letters: ['n']  },
    { rune: 'ᛁ', letters: ['i', 'y']  },
    { rune: 'ᛃ', letters: ['j']  },
    { rune: 'ᛈ', letters: ['p']  },
    { rune: 'ᛇ', letters: ['ï', 'æ']  },
    { rune: 'ᛉ', letters: ['z', 'š', 'ž']  },
    { rune: 'ᛊ', letters: ['s']  },
    { rune: 'ᛏ', letters: ['t']  },
    { rune: 'ᛒ', letters: ['b'] },
    { rune: 'ᛖ', letters: ['e']  },
    { rune: 'ᛗ', letters: ['m']  },
    { rune: 'ᛚ', letters: ['l']  },
    { rune: 'ᛜ', letters: ['ŋ']  },
    { rune: 'ᛞ', letters: ['d']  },
    { rune: 'ᛟ', letters: ['o', 'œ']  },
    //Special cases
    { rune: '×', letters: ['\'', ':']},
    { rune: 'ᛟ', letters: ['ö']},
    { rune: 'ᛟᚨ', letters: ['õ']},
    { rune: 'ᛖ', letters: ['ä']},
];

var youngerArray = [
    { rune: 'ᚠ', letters: ['f']},
    { rune: 'ᚢ', letters: ['u', 'v', 'w', 'ø', 'ü']},
    { rune: 'ᚦ', letters: ['þ', 'ð']  },
    { rune: 'ᚬ', letters: ['o', 'ą', 'æ', 'œ']},
    { rune: 'ᚱ', letters: ['r']  },
    { rune: 'ᚴ', letters: ['g', 'k', 'c', 'q']},
    { rune: 'ᚼ', letters: ['h']},
    { rune: 'ᚾ', letters: ['n']},
    { rune: 'ᛁ', letters: ['i', 'y', 'e', 'j']},
    { rune: 'ᛅ', letters: ['a', 'ä']},
    { rune: 'ᛦ', letters: ['ʀ']},
    { rune: 'ᛋ', letters: ['s', 'x', 'ž', 'š', 'z']},
    { rune: 'ᛏ', letters: ['t', 'd']},
    { rune: 'ᛒ', letters: ['p', 'b']},
    { rune: 'ᛘ', letters: ['m']},
    { rune: 'ᛚ', letters: ['l']},
    //Special cases
    { rune: 'ᚾᚴ', letters: ['ŋ']},
    { rune: '×', letters: ['\'', ':']},
    { rune: 'ᚬ', letters: ['ö']},
    { rune: 'ᛁᛅ', letters: ['õ']},
    { rune: 'ᛅ', letters: ['ä']},
];

var shortTwigArray = [
    { rune: 'ᚠ', letters: ['f']},
    { rune: 'ᚢ', letters: ['u', 'v', 'w', 'ø', 'ü']},
    { rune: 'ᚦ', letters: ['þ', 'ð']  },
    { rune: 'ᚭ', letters: ['o', 'ą', 'æ', 'œ']},
    { rune: 'ᚱ', letters: ['r']  },
    { rune: 'ᚴ', letters: ['g', 'k', 'c', 'q']},
    { rune: 'ᚽ', letters: ['h']},
    { rune: 'ᚿ', letters: ['n']},
    { rune: 'ᛁ', letters: ['i', 'y', 'e', 'j']},
    { rune: 'ᛆ', letters: ['a', 'ä']},
    { rune: 'ᛧ', letters: ['ʀ']},
    { rune: 'ᛌ', letters: ['s', 'x', 'ž', 'š', 'z']},
    { rune: 'ᛐ', letters: ['t', 'd']},
    { rune: 'ᛓ', letters: ['p', 'b']},
    { rune: 'ᛙ', letters: ['m']},
    { rune: 'ᛚ', letters: ['l']},
    //Special cases
    { rune: 'ᚿᚴ', letters: ['ŋ']},
    { rune: '×', letters: ['\'', ':']},
    { rune: 'ᚭ', letters: ['ö']},
    { rune: 'ᛁᛆ', letters: ['õ']},
    { rune: 'ᛆ', letters: ['ä']},
];

var noTwigArray = [
    { rune: 'ᛙ', letters: ['f']},
    { rune: '╮', letters: ['u', 'v', 'w', 'ø', 'ü']},
    { rune: 'ו', letters: ['þ', 'ð']  },
    { rune: 'ˎ', letters: ['o', 'ą', 'æ', 'œ', 'õ']},
    { rune: '◟', letters: ['r']  },
    { rune: 'ᛍ', letters: ['g', 'k', 'c', 'q']},
    { rune: 'ᚽ', letters: ['h']},
    { rune: '⸜', letters: ['n']},
    { rune: 'ᛁ', letters: ['i', 'y', 'e', 'j']},
    { rune: '⸝', letters: ['a', 'ä']},
    { rune: '⡄', letters: ['ʀ']},
    { rune: '╵', letters: ['s', 'x', 'ž', 'š', 'z']},
    { rune: '⸍', letters: ['t', 'd']},
    { rune: 'ި', letters: ['p', 'b']},
    { rune: '⠃', letters: ['m']},
    { rune: '⸌', letters: ['l']},
    //Special cases
    { rune: '×', letters: ['\'', ':']},
];

var angloArray = [
    { rune: 'ᚠ',letters: ['f', 'v'] },
    { rune: 'ᚢ',letters: ['u', 'ü'] },
    { rune: 'ᚦ',letters: ['þ', 'ð'] },
    { rune: 'ᚩ',letters: ['o'] },
    { rune: 'ᚱ',letters: ['r', 'ʀ']},
    { rune: 'ᚳ',letters: ['c', 'k', 'q'] },
    { rune: 'ᚷ',letters: ['g'] },
    { rune: 'ᚹ', letters: ['w'] },
    { rune: 'ᚻ',letters: ['h'] },
    { rune: 'ᚾ',letters: ['n'] },
    { rune: 'ᛁ',letters: ['i', 'y'] },
    { rune: 'ᛄ',letters: ['j'] },
    { rune: 'ᛇ', letters: ['ï', 'æ', 'ȝ']  },
    { rune: 'ᛈ', letters: ['p']  },
    { rune: 'ᛘ', letters: ['m']},
    { rune: 'ᛋ',letters: ['s', 'x', 'š', 'ž', 'z'] },
    { rune: 'ᛏ',letters: ['t'] },
    { rune: 'ᛒ',letters: ['b'] },
    { rune: 'ᛖ',letters: ['e'] },
    { rune: 'ᛗ',letters: ['m'] },
    { rune: 'ᛚ',letters: ['l'] },
    { rune: 'ᛝ', letters: ['ŋ'] },
    { rune: 'ᛟ', letters: ['o', 'œ']  },
    { rune: 'ᛞ',letters: ['d'] },
    { rune: 'ᚪ',letters: ['a'] },
    { rune: 'ᚨ', letters: ['a', 'æ'] },
    { rune: 'ᚣ',letters: ['y'] },
    { rune: 'ᛡ',letters: ['ö', 'õ'] },
    { rune: 'ᛠ',letters: ['ä'] },
    //Special cases
    { rune: 'ᚾᚴ', letters: ['ŋ']},
    { rune: '×', letters: ['\'', ':']},
];

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
    { rune: 'ᚴᛍ',letters: ['x'] },
];
      
// function textToRune(inputText: string): string[] {
//   	var inputArray = replaceSpelling(inputText).split('');
      
//     var elder = "";
//     var younger = "";
//     var shorttwig = "";
//     var notwig = "";
//     var anglo = "";
//     var medieval = "";
    
//     for(var i = 0; i < inputArray.length; i++)
//     {
//       	var letter = inputArray[i].toLowerCase();
// 		elder += getRunes(letter, elderArray);
// 		younger += getRunes(letter, youngerArray);
// 		shorttwig += getRunes(letter, shortTwigArray);
// 		notwig += getRunes(letter, noTwigArray);
// 		anglo += getRunes(letter, angloArray);
//         medieval += getRunes(letter, medievalArray);
//     }
    
//     return [elder, younger, shorttwig, notwig, anglo, medieval];
// };
        
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

function runeToText(inputRune: string): string {
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

        await writeFile(taskArgs.outputpath, medievalRunes.join('\n'));
    });

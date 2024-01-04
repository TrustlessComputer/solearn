npx hardhat deploy --tags 2 --network regtest
npx hardhat mint-perceptron --network regtest --model 'sample-models/2x2.json' 
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptoadz/000.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptoadz/001.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptoadz/002.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptopunks/000.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptopunks/001.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptopunks/002.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/moonbirds/000.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/moonbirds/001.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/moonbirds/002.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/nouns/000.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/nouns/001.png' --w 10 --h 10
npx hardhat eval-perceptron --network regtest --id '1' --offline false --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/nouns/002.png' --w 10 --h 10


npx hardhat eval-perceptron --network regtest --id '1' --offline true --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b' --img 'sample-images/2x2/cryptoadz/000.png'
npx hardhat get-perceptron --network regtest --id '3' --contract '0x8f301222E58ff320e43cc3E2777E15d4A838699b'



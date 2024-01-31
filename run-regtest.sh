# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '1' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_mini.json' --id '2' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_3conv.json' --id '3' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200
npx hardhat mint-model-id --network regtest --model 'sample-models/10x10.json' --id '4' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200
npx hardhat mint-model-id --network regtest --model 'sample-models/32x32_cifar.json' --id '5' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --maxlen 200

# call SC to evaluate image
npx hardhat eval-img --network regtest --id '4' --offline true --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest --id '4' --offline true --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest --id '4' --offline true --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest --id '4' --offline true --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --img 'sample-images/10x10/nouns/000.png'

npx hardhat eval-img --network regtest --id '3' --offline false --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042' --img 'sample-images/cifar10/airplane/0000.jpg'

# get info model from sc
npx hardhat get-model --network regtest --id '3' --contract '0xD03FA3E103A1ea309cFb43Aa2BD1B300566E0042'

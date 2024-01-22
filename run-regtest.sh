# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44'
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '2' --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44'
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_mini.json' --id '3' --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44'
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_3conv.json' --id '4' --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44'

# call SC to evaluate image
npx hardhat eval-img --network regtest --id '2' --offline true --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44' --img 'sample-images/10x10/nouns/000.png'

npx hardhat eval-img --network regtest --id '3' --offline true --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44' --img 'sample-images/cifar10/airplane/0000.jpg'

# get info model from sc
npx hardhat get-model --network regtest --id '0' --contract '0x639453f46C75C1b4a43a8FdBA27B03b916748a44'

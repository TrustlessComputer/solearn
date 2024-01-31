# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID

npx hardhat mint-model-id --network regtest --model 'sample-models/10x10.json' --id '0' --contract '0xF4e3F901DDf2F50B68e48123e317CfD37c2f7541'

# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '1' --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_mini.json' --id '2' --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_3conv.json' --id '3' --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073'


# call SC to evaluate image
npx hardhat eval-img --network regtest --id '1' --offline true --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073' --img 'sample-images/10x10/nouns/000.png'

npx hardhat eval-img --network regtest --id '3' --offline false --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073' --img 'sample-images/cifar10/airplane/0000.jpg'

# get info model from sc
npx hardhat get-model --network regtest --id '3' --contract '0x5c43Bd02645e07220f11275Bf9C4abDf9c90c073'

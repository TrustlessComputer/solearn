# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID

npx hardhat mint-model-id --network regtest --model 'sample-models/10x10.json' --id '0' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --maxlen 1000
npx hardhat mint-model-id --network regtest --model 'sample-models/32x32_cifar.json' --id '1' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --maxlen 6000

# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '1' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_mini.json' --id '2' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_3conv.json' --id '3' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c'


# call SC to evaluate image
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --img 'sample-images/10x10/nouns/000.png'

# npx hardhat eval-img --network regtest --id '3' --offline false --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c' --img 'sample-images/cifar10/airplane/0000.jpg'

# get info model from sc
npx hardhat get-model --network regtest --id '0' --contract '0x6dc2bB742561bB07eA8B22fA3C047F403b26456c'

# deploy SC
npx hardhat deploy --tags 2 --network regtest2

# mint model ID

npx hardhat mint-model-id --network regtest2 --model 'sample-models/10x10.json' --id '0' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --maxlen 5000
npx hardhat mint-model-id --network regtest2 --model 'sample-models/32x32_cifar.json' --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --maxlen 10000
npx hardhat mint-model-id --network regtest2 --model 'sample-models/128x128.json' --id '15' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --maxlen 10000

# npx hardhat mint-model-id --network regtest2 --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'
# npx hardhat mint-model-id --network regtest2 --model 'sample-models/cnn_10x10.json' --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'
# npx hardhat mint-model-id --network regtest2 --model 'sample-models/cnn_cifar_mini.json' --id '2' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'
# npx hardhat mint-model-id --network regtest2 --model 'sample-models/cnn_cifar_3conv.json' --id '3' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'


# call SC to evaluate image
npx hardhat eval-img --network regtest2 --id '0' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest2 --id '0' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest2 --id '0' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest2 --id '0' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/10x10/nouns/000.png'

npx hardhat eval-img --network regtest2 --id '1' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/cifar10/airplane/0000.jpg' > tmp.txt 2>&1
npx hardhat eval-img --network regtest2 --id '15' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/cifar10/airplane/0000.jpg'

# get info model from sc
npx hardhat get-model --network regtest2 --id '15' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'

npx hardhat test-iteration --network regtest2 --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'

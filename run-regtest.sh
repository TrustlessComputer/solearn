# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '4' --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE'
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '5' --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE'

# call SC to evaluate image
npx hardhat eval-img --network regtest --id '4' --offline false --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE' --img 'sample-images/10x10/cryptoadz/000.png' --w 10 --h 10
npx hardhat eval-img --network regtest --id '4' --offline false --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE' --img 'sample-images/10x10/cryptopunks/000.png' --w 10 --h 10

# get info model from sc
npx hardhat get-model --network regtest --id '4' --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE'

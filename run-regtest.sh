# deploy SC
npx hardhat deploy --tags 3 --network regtest

# mint model ID
npx hardhat mint-model-id --network regtest --model 'sample-models/10x10.json' --id '0' --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE'

# call SC to evaluate image
npx hardhat eval-img --network regtest --id '0' --offline false --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE' --img 'sample-images/10x10/cryptoadz/000.png' --w 10 --h 10
npx hardhat eval-img --network regtest --id '0' --offline false --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE' --img 'sample-images/10x10/cryptopunks/000.png' --w 10 --h 10

# get info model from sc
npx hardhat get-model --network regtest --id '0' --contract '0x3Ef48814d91D79927d16dA531931E1D6080cdcdE'

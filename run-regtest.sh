# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6'
npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '1' --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6'

# call SC to evaluate image
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6' --img 'sample-images/10x10/cryptoadz/000.png' --w 10 --h 10
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6' --img 'sample-images/10x10/cryptopunks/000.png' --w 10 --h 10
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6' --img 'sample-images/10x10/moonbirds/000.png' --w 10 --h 10
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6' --img 'sample-images/10x10/nouns/000.png' --w 10 --h 10

# get info model from sc
npx hardhat get-model --network regtest --id '0' --contract '0x117C9DE433695CE9D2E61665b20051DDB6f23Ee6'

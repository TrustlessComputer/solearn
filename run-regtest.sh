# deploy SC
npx hardhat deploy --tags 2 --network regtest

# mint model ID

npx hardhat mint-model-id --network regtest --model 'sample-models/10x10.json' --id '0' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --maxlen 5000
npx hardhat mint-model-id --network regtest --model 'sample-models/32x32_cifar.json' --id '1' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --maxlen 10000
npx hardhat mint-model-id --network regtest --model 'sample-models/24x24.json' --id '10' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --maxlen 10000

npx hardhat mint-model-id --network regtest --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0x711491991c02ac40Bf37974ce2aF67035FF4894e' --maxlen 10000

# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10_small.json' --id '0' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_10x10.json' --id '1' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_mini.json' --id '2' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'
# npx hardhat mint-model-id --network regtest --model 'sample-models/cnn_cifar_3conv.json' --id '3' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'


# call SC to evaluate image
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest --id '0' --offline true --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --img 'sample-images/10x10/nouns/000.png'

npx hardhat eval-img --network regtest --id '1' --offline true --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --img 'sample-images/cifar10/airplane/0000.jpg'

npx hardhat generate-text --network regtest --id '1' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --prompt 'ROMEO:' --togenerate 1

# get info model from sc
npx hardhat get-model --network regtest --id '0x4dd21efd1dbbf8a2f7d0122a828f5861fbb6f7d281c99385b62e3cb897248b1c' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'
npx hardhat get-model --network regtest --id '0x4dd21efd1dbbf8a2f7d0122a828f5861fbb6f7d281c99385b62e3cb897248b1c' --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B'

# upload models
npx hardhat mint-models --network regtest --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --folder '_models/' --maxlen 10000 
npx hardhat get-model-ids --network regtest --folder '_models/'
npx hardhat check-models --network regtest --contract '0x223EFb2b9FD3dfA26bDB9Cd5CebCB3511dBd089B' --folder '_models/'

# Deploy local node
npx hardhat deploy --tags 1 --network cudatest

npx hardhat mint-model-id --network cudatest --id '2' --model 'sample-models/shakespeare_simplernn.json' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --maxlen 10000
# npx hardhat mint-model-id --network cudatest --id '2' --model 'sample-models/shakespeare_lstm_small.json' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --maxlen 10000
# id '1' - 0xfFC4294Ac255E57317d3657B24c32dda94BDe399
# id '2' - 0xa40B58c9c9A9B30542646479faD1eE47457EcCEA


npx hardhat get-model --network cudatest --id '2' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8'

# npx hardhat generate-text --network cudatest --id '1' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network cudatest --id '2' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100
npx hardhat generate-text --network cudatest --id '1' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --prompt $'...' --togenerate 20 --seed 123 --temperature 1.0

npx hardhat gas-generate-text --network cudatest --id '1' --contract '0x4996d7f3ce984C59399A63BD3E7614882525D3F8' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20


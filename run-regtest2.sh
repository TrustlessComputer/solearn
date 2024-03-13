# Deploy local node
npx hardhat deploy --tags 1 --network regtest2

# npx hardhat mint-model-id --network regtest2 --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --maxlen 10000
npx hardhat mint-model-id --network regtest2 --id '1' --model 'sample-models/shakespeare_lstm_small.json' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --maxlen 10000

npx hardhat get-model --network regtest2 --id '2' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70'

# npx hardhat generate-text --network regtest2 --id '1' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network regtest2 --id '1' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network regtest2 --id '1' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --prompt $'...' --togenerate 20 --seed 123 --temperature 1.0

npx hardhat gas-generate-text --network regtest2 --id '1' --contract '0xCF71Bf8F3FaAa66546c5C9b4E2Dd8C34078Aac70' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20

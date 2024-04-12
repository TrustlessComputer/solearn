# Deploy local node
npx hardhat deploy --tags 1 --network regtest2

# npx hardhat mint-model-id --network regtest2 --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --maxlen 10000
# npx hardhat mint-model-id --network regtest2 --id '16050010' --model 'sample-models/shakespeare_lstm_small.json' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --maxlen 10000
npx hardhat mint-model-id --network regtest2 --id '16050010' --model 'sample-models/shakespeare_lstm_mini.json' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --maxlen 10000

npx hardhat get-model --network regtest2 --id '16050010' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

# npx hardhat generate-text --network regtest2 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network regtest2 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network regtest2 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'...' --togenerate 20 --seed 123 --temperature 1.0

npx hardhat gas-generate-text --network regtest2 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20

npx hardhat test-storage --network regtest2 --n 500000

npx hardhat test-storage-multi-contract --network regtest2 --n 500000

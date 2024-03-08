# Deploy local node
anvil --prune-history --order fifo --code-size-limit 4294967296 -m "test test test test test test test test test test test junk" --gas-limit 1000000000000 --block-time 3

npx hardhat deploy --tags 2 --network anvil

npx hardhat mint-model-id --network anvil --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10_small.json'
npx hardhat mint-model-id --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10.json'

npx hardhat mint-model-id --network anvil --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 10000
npx hardhat mint-model-id --network anvil --id '2' --model 'sample-models/shakespeare_lstm_small.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 10000
npx hardhat mint-model-id --network anvil --id '3' --model 'sample-models/shakespeare_lstm_mini.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 10000

npx hardhat get-model --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat eval-img --network anvil --id '2' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/001.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/002.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/001.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/002.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/001.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/002.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/000.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/001.png'
npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/002.png'

npx hardhat generate-text --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100
npx hardhat generate-text --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'Q' --togenerate 50

npx hardhat generate-text --network anvil --id '3' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'Q' --togenerate 100

npx hardhat gas-generate-text --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'
npx hardhat gas-generate-text --network anvil --id '3' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat test-iteration --network anvil --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# npx hardhat mint-model-id --network anvil --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_cifar_mini.json'

# npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/cifar10/airplane/0000.jpg'

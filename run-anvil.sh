# Deploy local node
# anvil --prune-history --order fifo --code-size-limit 4294967296 -m "test test test test test test test test test test test junk" --gas-limit 100000000000 --block-time 3

npx hardhat deploy --tags 1 --network anvil

npx hardhat mint-model-id --network anvil --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10_small.json'
npx hardhat mint-model-id --network anvil --id '2' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10.json'

# npx hardhat get-model --network anvil --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat eval-img --network anvil --id '1' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/000.png'
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

# npx hardhat mint-model-id --network anvil --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_cifar_mini.json'

# npx hardhat eval-img --network anvil --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/cifar10/airplane/0000.jpg'

npx hardhat generate-text --network anvil --id '1' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat mint-melody-model-id --network anvil --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/little_musicnet.json' --maxlen 100000

npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

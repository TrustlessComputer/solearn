# Deploy local node
export NODE_OPTIONS="--max-old-space-size=8192"
# npx hardhat node

# npx hardhat deploy --tags 2 --network localhost

# npx hardhat mint-model-id --network localhost --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10_small.json'
# npx hardhat mint-model-id --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10.json'
npx hardhat mint-model-id --network localhost --id '0' --model 'sample-models/10x10.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 200
npx hardhat mint-model-id --network localhost --id '1' --model 'sample-models/32x32_cifar.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat mint-model-id --network localhost --id '2' --model 'sample-models/shakespeare_lstm.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 10000
npx hardhat mint-model-id --network localhost --id '3' --model 'sample-models/shakespeare_lstm.json' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --maxlen 10000

# npx hardhat get-model --network localhost --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/001.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/002.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/001.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/002.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/001.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/002.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/000.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/001.png'
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/002.png'

# npx hardhat mint-model-id --network localhost --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_cifar_mini.json'

# npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/cifar10/airplane/0000.jpg'

npx hardhat generate-text --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat generate-text --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'R' --togenerate 1 --generatepertx 1

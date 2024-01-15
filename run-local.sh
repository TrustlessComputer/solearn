# Deploy local node
# npx hardhat node

# npx hardhat deploy --tags 3 --network localhost

npx hardhat mint-model-id --network localhost --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_10x10_small.json'

# npx hardhat get-model --network localhost --id '0' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/000.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/001.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/002.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/000.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/001.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptopunks/002.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/000.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/001.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/moonbirds/002.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/000.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/001.png' --w 10 --h 10
npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/nouns/002.png' --w 10 --h 10

# npx hardhat mint-model-id --network localhost --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --model 'sample-models/cnn_cifar_mini.json'

# npx hardhat eval-img --network localhost --id '0' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/cifar10/airplane/0000.jpg' --w 32 --h 32

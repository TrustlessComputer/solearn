# Deploy local node
export NODE_OPTIONS="--max-old-space-size=8192"
npx hardhat node

# ModelRegister contract is automatically deployed

# ImageClassifier
npx hardhat run scripts/deploy-image-model.ts --network localhost

npx hardhat eval-img --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptoadz/000.png'

npx hardhat get-image-model --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# TextRNN
npx hardhat run scripts/deploy-textrnn-model.ts --network localhost

npx hardhat generate-text --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-textrnn-model --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts --network localhost

npx hardhat generate-melody --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network localhost --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# Testing contract storage
npx hardhat test-storage-multi-contract --network localhost --n 500000

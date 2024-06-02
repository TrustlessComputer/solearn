# Deploy local node
anvil --prune-history --order fifo --code-size-limit 4294967296 -m "test test test test test test test test test test test junk" --gas-limit 1000000000000 --block-time 3

# Deploy ModelRegister contract
npx hardhat deploy --tags 1 --network anvil

# ImageClassifier
npx hardhat run scripts/deploy-image-model.ts --network anvil

npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptoadz/000.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptoadz/001.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptoadz/002.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptopunks/000.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptopunks/001.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/cryptopunks/002.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/moonbirds/000.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/moonbirds/001.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/moonbirds/002.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/nouns/000.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/nouns/001.png'
npx hardhat eval-img --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/nft/nouns/002.png'

npx hardhat get-image-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# TextRNN
npx hardhat run scripts/deploy-textrnn-model.ts --network anvil

npx hardhat generate-text --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-textrnn-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts --network anvil

npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# Testing contract storage
npx hardhat test-storage-multi-contract --network anvil --n 500000
 
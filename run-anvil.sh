# Deploy local node
anvil --prune-history --order fifo --code-size-limit 4294967296 -m "test test test test test test test test test test test junk" --gas-limit 1000000000000 --block-time 3

# EternalAI
npx hardhat deploy --tags 1 --network anvil

npx hardhat get-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

npx hardhat eval-img --network anvil --id '1' --offline true --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --img 'sample-images/10x10/cryptoadz/000.png'

# MelodyRNN
npx hardhat generate-text --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 50 --steplen 1 --output "outputs/vgm.mid"
npx hardhat generate-melody --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' --count 1 --steplen 50 --output "outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network anvil --id '1' --contract '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'

# Testing contract storage
npx hardhat test-storage-multi-contract --network anvil --n 500000
 
# EternalAI
npx hardhat deploy --tags 1 --network localhost

npx hardhat get-model --network localhost --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

npx hardhat eval-img --network localhost --id '1' --offline true --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --img 'sample-images/10x10/cryptoadz/000.png'

# MelodyRNN
npx hardhat generate-text --network localhost --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat generate-melody --network localhost --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --count 50 --steplen 1 --output "outputs/vgm.mid"
npx hardhat generate-melody --network localhost --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --count 1 --steplen 50 --output "outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network localhost --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

# Testing contract storage
npx hardhat test-storage-multi-contract --network localhost --n 500000

# Deploy ModelRegister contract
npx hardhat deploy --tags 1 --network regtest3

# ImageClassifier
npx hardhat run scripts/deploy-image-model.ts

npx hardhat eval-img --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --img 'sample-images/10x10/cryptoadz/000.png'

npx hardhat get-image-model --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

# TextRNN
npx hardhat run scripts/deploy-textrnn-model.ts

npx hardhat generate-text --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-textrnn-model --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts

npx hardhat generate-melody --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --count 50 --steplen 1 --output "outputs/vgm.mid"
npx hardhat generate-melody --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361' --count 1 --steplen 50 --output "outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network regtest3 --id '1' --contract '0x987c7F1f0e0cec104b18Ed16e0139dc77Fa18361'

# Testing contract storage
npx hardhat test-storage-multi-contract --network regtest3 --n 500000

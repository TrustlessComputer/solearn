# Deploy ModelRegister contract
npx hardhat deploy --tags 1 --network regtest3

# ImageClassifier
npx hardhat run scripts/deploy-image-model.ts --network regtest3

npx hardhat eval-img --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764' --img 'sample-images/nft/cryptoadz/000.png'

npx hardhat get-image-model --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764'

# TextRNN
npx hardhat run scripts/deploy-textrnn-model.ts --network regtest3

npx hardhat generate-text --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-textrnn-model --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts --network regtest3

npx hardhat generate-melody --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network regtest3 --id '1' --contract '0xfC662501feDBe154Dc72004f26033895501d7764'

# Testing contract storage
npx hardhat test-storage-multi-contract --network regtest3 --n 500000

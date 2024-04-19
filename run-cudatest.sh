# Deploy ModelRegister contract
npx hardhat deploy --tags 1 --network cudatest

# EternalAI
npx hardhat run scripts/deploy-eai-model.ts

npx hardhat eval-img --network cudatest --id '1' --offline true --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --img 'sample-images/10x10/cryptoadz/000.png'

npx hardhat generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-model --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts

npx hardhat generate-melody --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --count 50 --steplen 1 --output "outputs/vgm.mid"
npx hardhat generate-melody --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --count 1 --steplen 50 --output "outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'

# Testing contract storage
npx hardhat test-storage-multi-contract --network cudatest --n 500000

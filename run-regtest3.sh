# Deploy ModelRegister contract
npx hardhat deploy --tags 1 --network regtest3

# ImageClassifier
npx hardhat run scripts/deploy-image-model.ts --network regtest3

npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptoadz/000.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptoadz/001.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptoadz/002.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptopunks/000.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptopunks/001.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/cryptopunks/002.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/moonbirds/000.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/moonbirds/001.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/moonbirds/002.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/nouns/000.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/nouns/001.png'
npx hardhat eval-img --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --img 'sample-images/nft/nouns/002.png'

npx hardhat get-image-model --network regtest3 --id '1000002' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13'

# TextRNN
npx hardhat run scripts/deploy-textrnn-model.ts --network regtest3

npx hardhat generate-text --network regtest3 --id '1' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat get-textrnn-model --network regtest3 --id '1' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13'

# MelodyRNN
npx hardhat run scripts/deploy-melody-model.ts --network regtest3

npx hardhat generate-melody --network regtest3 --id '1' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network regtest3 --id '1' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network regtest3 --id '1' --contract '0x0D8eEd4f3E1D19bCd0CC13BD093C01048c88ee13'

# Testing contract storage
npx hardhat test-storage-multi-contract --network regtest3 --n 500000

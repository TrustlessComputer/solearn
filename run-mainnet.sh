npx hardhat run scripts/deploy-eai-model.ts --network mainnet
npx hardhat run scripts/deploy-melody-model.ts --network mainnet

npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptoadz/001.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptoadz/002.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptopunks/001.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/cryptopunks/002.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/moonbirds/001.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/moonbirds/002.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/nouns/000.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/nouns/001.png'
npx hardhat eval-img --network mainnet --id '100013' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --img 'sample-images/10x10/nouns/002.png'

npx hardhat generate-text --network mainnet --id '100016' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --prompt $'Mrs. Dursley had had a nice, normal day.' --togenerate 100 --generatepertx 10
npx hardhat generate-text --network mainnet --id '100025' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat generate-melody --network mainnet --id '100029' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --count 50 --steplen 1 --output "_outputs/beethoven.mid"
npx hardhat generate-melody --network mainnet --id '100029' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --count 1 --steplen 50 --output "_outputs/beethoven_stateful.mid"
npx hardhat generate-melody --network mainnet --id '100030' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --count 50 --steplen 1 --output "_outputs/pop.mid"
npx hardhat generate-melody --network mainnet --id '100030' --offline true --contract '0xB0e91e2Aa27330434Bfc33fF5314C796eD3Ad3c6' --count 1 --steplen 50 --output "_outputs/pop_stateful.mid"


npm run deployModelCollection:anvil

npx hardhat run scripts/deploy-eai-model.ts --network regtest3
npx hardhat run scripts/deploy-melody-model.ts --network regtest3

# npx hardhat get-model --network regtest3 --id '0' --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f'

npx hardhat eval-img --network regtest3 --id '1' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptoadz/000.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptoadz/001.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptoadz/002.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptopunks/000.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptopunks/001.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/cryptopunks/002.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/moonbirds/000.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/moonbirds/001.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/moonbirds/002.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/nouns/000.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/nouns/001.png'
npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/10x10/nouns/002.png'

# npx hardhat mint-model-id --network regtest3 --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --model 'sample-models/cnn_cifar_mini.json'

# npx hardhat eval-img --network regtest3 --id '0' --offline true --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --img 'sample-images/cifar10/airplane/0000.jpg'

npx hardhat generate-text --network regtest3 --id '2' --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

npx hardhat mint-melody-model-id --network regtest3 --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --model 'sample-models/little_musicnet.json' --maxlen 100000

npx hardhat generate-melody --network regtest3 --id '1' --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --count 50 --steplen 1 --output "_outputs/vgm.mid"
npx hardhat generate-melody --network regtest3 --id '1' --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f' --count 1 --steplen 50 --output "_outputs/vgm_stateful.mid"

npx hardhat get-melody-model --network regtest3 --id '1' --contract '0x2ECdC4B57b6993a6897019a4FF70Ff1DB62A2B8f'

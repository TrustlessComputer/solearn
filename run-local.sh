# Deploy local node
# npx hardhat node

npx hardhat deploy --tags 3 --network localhost

npx hardhat mint-model-id --network localhost --contract '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' --model 'sample-models/10x10.json'

npx hardhat eval-img --network localhost --id '0' --offline true --contract '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' --img 'sample-images/10x10/cryptoadz/000.png' --w 10 --h 10

# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptoadz/000.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptoadz/001.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptoadz/002.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptopunks/000.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptopunks/001.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/cryptopunks/002.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/moonbirds/000.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/moonbirds/001.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/moonbirds/002.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/nouns/000.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/nouns/001.png' --w 2 --h 2
# npx hardhat eval-img --network hardhat --img 'sample-images/2x2/nouns/002.png' --w 2 --h 2

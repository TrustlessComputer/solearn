npx hardhat deploy --tags 2 --network localhost
npx hardhat mint-perceptron --network localhost --tokenid 0 --model sample-models/artblock20.json
npx hardhat eval-perceptron --network localhost --tokenid 0 --img 'sample-images/artblock20/00-Friendship Bracelets/000.png'
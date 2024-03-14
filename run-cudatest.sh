# Deploy local node
npx hardhat deploy --tags 1 --network cudatest

npx hardhat mint-model-id --network cudatest --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '2' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '3' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '5' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000

npx hardhat get-model --network cudatest --id '3' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892'

# npx hardhat generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\n' --togenerate 20
npx hardhat generate-text --network cudatest --id '4' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '5' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'...' --togenerate 20 --seed 123 --temperature 1.0

npx hardhat gas-generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20


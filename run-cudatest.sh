# Deploy local node
npx hardhat deploy --tags 1 --network cudatest

npx hardhat mint-model-id --network cudatest --id '1' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '2' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '3' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '5' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '6' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '7' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '8' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '10' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '11' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '12' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000
npx hardhat mint-model-id --network cudatest --id '18' --model 'sample-models/shakespeare_simplernn.json' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --maxlen 10000

# 7 - No CUDA, no event
# 8 - No CUDA, with event
# 10 - CUDA, with event
# 11 - No CUDA, with event
# 18 - CUDA, with event
# 17 - No CUDA, with event

npx hardhat get-model --network cudatest --id '3' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892'

# npx hardhat generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\n' --togenerate 20
npx hardhat generate-text --network cudatest --id '4' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '5' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '6' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '7' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '8' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '9' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '10' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20 --cuda 1
npx hardhat generate-text --network cudatest --id '11' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20 --cuda 0
npx hardhat generate-text --network cudatest --id '18' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'Q' --togenerate 10 --cuda 1
npx hardhat generate-text --network cudatest --id '19' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'Q' --togenerate 10 --cuda 0

npx hardhat gas-generate-text --network cudatest --id '1' --contract '0xa2EEC1912c2dC5627b98FD704996f8b37551a892' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20


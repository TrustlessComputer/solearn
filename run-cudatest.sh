# Deploy local node
npx hardhat deploy --tags 1 --network cudatest

npx hardhat get-model --network cudatest --id '3' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75'

# npx hardhat generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:' --togenerate 100
npx hardhat generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\n' --togenerate 20
npx hardhat generate-text --network cudatest --id '4' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '5' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '6' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '7' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '8' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '9' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20
npx hardhat generate-text --network cudatest --id '10' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20 --cuda 1
npx hardhat generate-text --network cudatest --id '11' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20 --cuda 0
npx hardhat generate-text --network cudatest --id '18' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'Q' --togenerate 10 --cuda 1
npx hardhat generate-text --network cudatest --id '19' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'Q' --togenerate 10 --cuda 0

npx hardhat gas-generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 20

npx hardhat generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'t' --togenerate 1 --generatepertx 1

npx hardhat generate-text --network cudatest --id '1' --contract '0x1D19Db739A466c156b007B8cC18687Eb21434D75' --prompt $'ROMEO:\nIs the day so young?' --togenerate 100 --generatepertx 10

import * as hardhat from "hardhat";
import * as assert from "assert";

const {network} = hardhat;

async function main() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const melodyRNNAddress = config.melodyRNNAddress;
    assert.ok(
        melodyRNNAddress,
        `Missing ${networkName}_MELODY_ADDRESS from environment variables!`
    );

        await hardhat.run('verify:verify', {
            address: melodyRNNAddress,
            contract: 'contracts/MelodyRNN.sol:MelodyRNN',
        })
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
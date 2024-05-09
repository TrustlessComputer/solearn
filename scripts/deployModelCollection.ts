import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';

async function deployModelCollection() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const ModelCollection = await ethers.getContractFactory('ModelCollection');
    const modelCollectionAddress = config.collectionAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.collectionAddress,
                ModelCollection,
            );
            console.log(`Contract ModelCollection has been updated to address ${config.collectionAddress}`);
            return config.collectionAddress;
        })() :
        await (async () => {
            const name = "Model"
            const symbol = "MDL"
            const mintPrice = ethers.utils.parseEther('100');
            const royaltyReceiver = (await ethers.getSigners())[0].address
            const royalPortion = 20_00;
            const nextModelId = 1000001;

            const modelCollection = await upgrades.deployProxy(
                ModelCollection,
                [
                    name,
                    symbol,
                    mintPrice,
                    royaltyReceiver,
                    royalPortion,
                    nextModelId
                ]
            );
            await modelCollection.deployed();

            console.log(`Contract ModelCollection has been deployed to address ${modelCollection.address}`);
            return modelCollection.address;
        })();
    console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollectionAddress}`);
}

deployModelCollection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

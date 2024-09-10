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
            const name = "Eternal AI"
            const symbol = ""
            const mintPrice = ethers.parseEther('0');
            const royaltyReceiver = '0x451064E5B968858cD54f227Dba7b7F419eAC5BA9'
            const royalPortion = 5_00;
            const nextModelId = 100_001;

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
            await modelCollection.waitForDeployment();

            console.log(`Contract ModelCollection has been deployed to address ${modelCollection.target}`);
            return modelCollection.target;
        })();
    console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollectionAddress}`);
}

deployModelCollection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

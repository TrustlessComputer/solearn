import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';
import { deployOrUpgrade } from './lib/utils';
import { ModelCollection } from '../typechain-types';

async function deployModelCollection() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const name = "Eternal AI"
    const symbol = ""
    const mintPrice = ethers.parseEther('0');
    const royaltyReceiver = '0x451064E5B968858cD54f227Dba7b7F419eAC5BA9'
    const royalPortion = 5_00;
    const nextModelId = 100_001;
    
    const constructorParams = [
        name,
        symbol,
        mintPrice,
        royaltyReceiver,
        royalPortion,
        nextModelId
    ];
    
    const modelCollection = (await deployOrUpgrade(
        config.collectionAddress, 
        "ModelCollection", 
        constructorParams, 
        config, 
        true
    ) as unknown) as ModelCollection;
        
    console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollection.target}`);
}

deployModelCollection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

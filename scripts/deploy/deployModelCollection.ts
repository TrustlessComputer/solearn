import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';
import { deployOrUpgrade } from '../lib/utils';
import { ModelCollection } from '../../typechain-types';

async function deployModelCollection() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const treasuryAddress = config.treasuryAddress;
    assert.ok(
        treasuryAddress,
        `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
    );

    const name = "Eternal AI"
    const symbol = ""
    const mintPrice = ethers.parseEther('0');
    const royaltyReceiver = treasuryAddress;
    const royalPortion = 5_00;
    const nextModelId = 22219;
    
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

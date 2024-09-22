import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';
import { deployOrUpgrade } from '../lib/utils';
import { ModelCollectionERC20 } from '../../typechain-types';

async function deployModelCollectionERC20() {
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
    const nextModelId = 100_001;
    const token = "0xCDbE9D69d5d9a98D85384C05b462D16A588B53FA";
    
    const constructorParams = [
        name,
        symbol,
        mintPrice,
        royaltyReceiver,
        royalPortion,
        nextModelId,
        token,
    ];
    
    const modelCollectionERC20 = (await deployOrUpgrade(
        config.collectionAddress, 
        "ModelCollectionERC20", 
        constructorParams, 
        config, 
        true
    ) as unknown) as ModelCollectionERC20;
        
    console.log(`${networkName}_COLLECTION_ADDRESS=${modelCollectionERC20.target}`);
}

deployModelCollectionERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

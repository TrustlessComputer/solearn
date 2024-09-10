import assert from 'assert';
import { ethers, network, upgrades } from 'hardhat';
import { WorkerHub } from '../typechain-types';

async function addWorkerToModel() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();
    const WorkerHub = await ethers.getContractFactory('WorkerHub');

    const workerHubAddress = config.workerHubAddress;
    assert.ok(
        workerHubAddress,
        `Missing ${networkName}_WORKERHUB_ADDRESS from environment variables!`
    );

    const modelAddress = "0x71F5aCA42b4E428295366d09c2c02388F84021F2";
    const workerAddresses = [
        "0x53588a372da4ce00472aa0104b1eb35a9b872ec0",
        "0xc8d9af95715822fb122b2f977e15f13697d0aec6",
        "0xb3ba0135bb09c12698b982c54d9a569a4e602b66",
        "0xff51589567dd9fd72ccea920acbe30b1f576a52d",
        "0xaa474c80f2030484aa43b70d5c42749cd284ea41",
        "0x6661681af2c278c882aa4cee6832e7a6214259eb",
        "0x9695d6f4e8da5bb5a029ee7ef603e465e3f117fa",
        "0x0bb3dad373d6304d7a52d378e683acea95c6c29c",
        "0xd29339a105ae04f9a94b59689a85d035d28c832e",
        "0xdea892cb916c6753ac6469f6914d8a986382ba40",
        "0x75c4cb694ac195d36911f3e1636ac151766db3da",
        "0x0deb82005479c482a3fae15110821167ee515b5e",
        "0x53f91140915432c17b75d7547b9849ca0600c953",
        "0x2491661364e13f6bf2c5d361a5704b763a33c257",
        "0xd82f43e346e653f7deed5805f771cf1f894fae1d",
        "0x373ba7991dc6ae8f73aae55602c50c13457dcd25",
        "0xde14ab59d896204d3468fb7fe775af387c871e69",
        "0x018db666d8377fbf336c12f1ddc44c2c2d481544",
        "0xbe845a1c9e1ed63db6c367fe4d0710da19b7ff78",
        "0x6f7d389728335ea30029d8d71e73ee3c8a5bae76",
        "0x0f5f19e0174c71c3467f0a91edaf71505d761168",
        "0x6abf916eb17df05c623db65a5d4f3073e05683b9",
        "0x5e5795449d9afe7021dc06ee98dc897b2cbf3f74",
        "0x4c489482ecc88cd230433395202b9b5c9310a31f",
        "0xd41f2593aa33ca16ae90aec238ea02c8cff64c1e",
        "0x22961b8b880fce028e509de720957dfaf950e070",
        "0x99e4dd9460eadd244ca1fc6cdd946b61fe070dc1",
    ];

    const workerHub = WorkerHub.attach(workerHubAddress) as WorkerHub;
    for(const worker of workerAddresses) {
        await (await workerHub.forceChangeModelForMiner(worker, modelAddress)).wait();
    }
}

addWorkerToModel()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

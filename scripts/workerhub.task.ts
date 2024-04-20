import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";

task("get-pending-max-multi")
    .addOptionalParam("workerhub", "worker_hub contract address", "0x5E077E883b9b44CC5213140c87d98DAB35E6390e", types.string)
    .addOptionalParam("model", "model contract address", "0x0964Eb14A7DF17f1B5b56c43f2d9B5b8873d573C", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers } = hre;
        const workerHub = await ethers.getContractAt('WorkerHub', taskArgs.workerhub);
        const pendingRequests = await workerHub.getModelUnresolvedInferences(taskArgs.model);
        console.log(pendingRequests.length);
        console.log(new Date());
    });

task("get-submission")
    .addOptionalParam("worker", "worker_hub contract address", "0x5E077E883b9b44CC5213140c87d98DAB35E6390e", types.string)
    .addOptionalParam("model", "model contract address", "0x0964Eb14A7DF17f1B5b56c43f2d9B5b8873d573C", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers } = hre;
        const workerHub = await ethers.getContractAt('WorkerHub', taskArgs.workerhub);
        const pendingRequests = await workerHub.getModelUnresolvedInferences(taskArgs.model);
        console.log(pendingRequests.length);
        console.log(new Date());
    });

import { task, types } from "hardhat/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";

task("get-pending-model")
    .addOptionalParam("workerhub", "worker_hub contract address", "0x5E077E883b9b44CC5213140c87d98DAB35E6390e", types.string)
    .addOptionalParam("model", "model contract address", "0x0964Eb14A7DF17f1B5b56c43f2d9B5b8873d573C", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers } = hre;
        const workerHub = await ethers.getContractAt('WorkerHub', taskArgs.workerhub);
        const pendingRequests = await workerHub.getModelUnresolvedInferences(taskArgs.model);

        const workerTasks: any[] = [];
        for (let i = 0; i < 20; ++i) workerTasks.push([]);
        for (const request of pendingRequests) workerTasks[request.requestId.toNumber() % 20].push(request.requestId);

        const workerTaskCount = workerTasks.map(arr => arr.length);
        console.log(pendingRequests.length);
        console.log(workerTaskCount);
        console.log(new Date());
    });

task("get-pending-all")
    .addOptionalParam("workerhub", "worker_hub contract address", "0x5E077E883b9b44CC5213140c87d98DAB35E6390e", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers } = hre;
        const workerHub = await ethers.getContractAt('WorkerHub', taskArgs.workerhub);
        const pendingRequests = await workerHub.getUnresolvedInferences();

        const workerTasks: any[] = [];
        for (let i = 0; i < 20; ++i) workerTasks.push([]);
        for (const request of pendingRequests) workerTasks[request.requestId.toNumber() % 20].push(request.requestId);

        const workerTaskCount = workerTasks.map(arr => arr.length);
        console.log(pendingRequests.length);
        console.log(workerTaskCount);
        console.log(new Date());
    });

task("get-latest-submit")
    .addOptionalParam("workerhub", "worker_hub contract address", "0x5E077E883b9b44CC5213140c87d98DAB35E6390e", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers } = hre;
        const workerHub = await ethers.getContractAt('WorkerHub', taskArgs.workerhub);

        const workers = [
            {
                privateKey: '0x9974b7457cb2f8213f8603fdefc7ae362bdc5c3a46c8805f307a7093a96e39e2',
                address: '0x5Ad06e5fCDcBE9be8e416dF728354fCcff7B904e'
            },
            {
                privateKey: '0xf341fdc0d482a7e3f2803443e95588d11b4e1a8536a9573033f167ea59c729eb',
                address: '0x19EE67fe6f7018E104decF019397d3ec27e4BD56'
            },
            {
                privateKey: '0x69607635e0637b073b81292b3ad4d4b42d65872b638968a37f65ef62865e0c31',
                address: '0x0047e1a6ec8B77c5A861A42621820A77116D4a2A'
            },
            {
                privateKey: '0x46bd3c5ded39d9c459ab719c74eb4335c84a74f3d3fd242dd8462816abd32991',
                address: '0x5Fa9A719d5452378c96c9c9234C9Cad683B3Ec0E'
            },
            {
                privateKey: '0x1fedd1b054840a984e7bdbbacb8653a19c8ddf0769d158e8abab72ea3a5cb6eb',
                address: '0x971cA154dA3F21c0D15D45d57Df26D049497167c'
            },
            {
                privateKey: '0x33cbfac0ccdb27983d36c6fa5c89aa6169f1ae85100b4ce94becce33f98a2a20',
                address: '0xFB5E1D02F5A90DA35595A6C216DeB42aFAf9ac34'
            },
            {
                privateKey: '0x942a565d7c45617953d23e06337cb616ce564e23ebb07f8b3922209df277309d',
                address: '0x5ad15573293967F256CA146d57754996248324f4'
            },
            {
                privateKey: '0xd23869c9d8891b46769641d77ad169b4c49a593d94b5e28b8a515cd63e35f315',
                address: '0x64d905285cDa14Ccb7Cf4F38A6C0C61059B7DB6A'
            },
            {
                privateKey: '0xfb2e0608e4c579452a284aa9249113e1cf066c2b177e2b28cfa8223140b9b843',
                address: '0x4717dcB0cfEecE19A175ef8Ae95f78b37739Ad03'
            },
            {
                privateKey: '0x7282555efebf2e261c6c2c4fc97bc95a4d59025ed5a3186a4017d775df89f87e',
                address: '0x4457bd4531fAd0f228ED65Ac554c314FC586bf63'
            },
            // {
            //     privateKey: '0x49899a82804fbda10ebfff4f3bae1dbac1edaadfe3c5ece6cc070292460472ca',
            //     address: '0x7796D6D275dC1D1576766215c6bb35d70C6F76fA'
            // },
            // {
            //     privateKey: '0x586d1d1e79d2e064b0c30e3333bd713cf2bf0a23ac00e896e47e6833035efc98',
            //     address: '0x0A55D4b562b53AA830D43334502cb964bbfd1856'
            // },
            // {
            //     privateKey: '0xdc94db062ecc21430fc2c4a788f4421b1039763a32c52fb5b6ef546a8a161549',
            //     address: '0x2C3f7860e40d386587Ca2C290c40B1A4611725F1'
            // },
            // {
            //     privateKey: '0xb968916e8136a81e64f9ac56320d28e156f4b442465aed7592e12b8acbc0be75',
            //     address: '0x609bb83A3acC6b29aD534ce11873a93268154d6e'
            // },
            // {
            //     privateKey: '0x9caef1e3345797be8f110ec62e6e7272054ca44c5337ff6631158b99003b9fe2',
            //     address: '0xc05623B02468EdB4E49f6D56dd1a95EB1bFa2a65'
            // },
            // {
            //     privateKey: '0x06c1b551e7c094a75353002cf899b51dcab8e87e6706c7e0fe09a3740a9bfe41',
            //     address: '0x329fC1d45B006e0D6dA79b147c89AD224dcb3785'
            // },
            // {
            //     privateKey: '0xaa8af7aa95fde120067238fc4f5bdc9d5ad38a31d592937f3965786570676cee',
            //     address: '0x299ba11C3783743FEcEeF7A4112b40e5aA65890d'
            // },
            // {
            //     privateKey: '0xfbfa463202919af9e381f420ab7523ccca0cba5d551ce568c4b52fcc9d27ffa9',
            //     address: '0x9F9E21a89006A30075D15e32FdaE889632daa95f'
            // },
            // {
            //     privateKey: '0x5fffdf6bc6b47689c959147a9f34b406f6cd5dc9793812ea9d912f031d1062d4',
            //     address: '0x8cdC8949E712C7F55FF76B9966c34531093e5D73'
            // },
            // {
            //     privateKey: '0xcfbc9a27a79e67a2137b7d5de190ead029ed9a6dbaf7b0d30fbf0bc97801ec37',
            //     address: '0x8E68B6990902b4dB627ef1eF328167CA21E24F63'
            // }
        ];
        
        for(const worker of workers) {
            const filter = workerHub.filters.ResultSubmission(null, worker.address);
            const events = await workerHub.queryFilter(filter);
            const blockNumbers = events.map(event => event.blockNumber);
            const lastBlockNumber = Math.max(...blockNumbers);
            const lastBlock = await ethers.provider.getBlock(lastBlockNumber);
            const duration = Date.now() - lastBlock.timestamp * 1000;
            console.log(worker.address, `${duration / 1000 / 60} minutes`);
        }
    });

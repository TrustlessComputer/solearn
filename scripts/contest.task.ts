import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import sharp from 'sharp';
import { NonceManager } from "@ethersproject/experimental";

task("contest-create", "create model contest")
    .addOptionalParam("accuracy", "accuracy", 1, types.int)
    .addOptionalParam("w", "perceptron input image width", 28, types.int)
    .addOptionalParam("h", "perceptron input image height", 28, types.int)
    .addOptionalParam("evalblocks", "blocks for evaluation", 50, types.int)
    .addOptionalParam("contract", "contract address", "", types.string)
    .setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts } = hre;
        const { modelMinter: signerAddress } = await getNamedAccounts();
        const signer = await ethers.getSigner(signerAddress);

        let contractAddress = taskArgs.contract;
        if (contractAddress === "") {
            const C = await deployments.get('Contests');
            contractAddress = C.address;
        }
        const c = await ethers.getContractAt("Contests", contractAddress, signer);
        let { w, h } = taskArgs;        
        
        const tokenDeployed = await deployments.get('RewardToken');
        const token = await ethers.getContractAt("RewardToken", tokenDeployed.address, signer);
        const tx0 = await token.approve(contractAddress, ethers.utils.parseEther("0.01"));
        await tx0.wait();
        const tx = await c.createContest(ethers.utils.parseEther("0.01"), taskArgs.accuracy, w * h * 3, taskArgs.evalblocks);

        await tx.wait();
        console.log("tx:", tx);
    });

task("contest-enter", "submit model to contest")
	.addOptionalParam("contract", "contract address", "", types.string)
	.addOptionalParam("modelid", "model id", 1, types.int)
	.addOptionalParam("contestid", "contest id", 1, types.int)
	.setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
		const { ethers, deployments, getNamedAccounts } = hre;
		const { modelMinter: signerAddress } = await getNamedAccounts();
		const signer = await ethers.getSigner(signerAddress);

		let contractAddress = taskArgs.contract;
		if (contractAddress === "") {
			const C = await deployments.get('Contests');
			contractAddress = C.address;
		}
		const c = await ethers.getContractAt("Contests", contractAddress, signer);
		const tx = await c.enterContest(taskArgs.contestid, taskArgs.modelid);

		await tx.wait();
		console.log("tx:", tx);
	});

task("contest-show", "show contest info")
	.addOptionalParam("contract", "contract address", "", types.string)
	.addOptionalParam("contestid", "contest id", 1, types.int)
	.setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
		const { ethers, deployments, getNamedAccounts } = hre;
		const { modelMinter: signerAddress } = await getNamedAccounts();
		const signer = await ethers.getSigner(signerAddress);

		let contractAddress = taskArgs.contract;
		if (contractAddress === "") {
			const C = await deployments.get('Contests');
			contractAddress = C.address;
		}
		const c = await ethers.getContractAt("Contests", contractAddress, signer);

		const result = await c.showContest(taskArgs.contestid);

		console.log("result:", result);
	});

task("contest-finalize", "submit model to contest")
	.addOptionalParam("contract", "contract address", "", types.string)
	.addOptionalParam("contestid", "contest id", 1, types.int)
	.setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
		const { ethers, deployments, getNamedAccounts } = hre;
		const { modelMinter: signerAddress } = await getNamedAccounts();
		const signer = await ethers.getSigner(signerAddress);

		let contractAddress = taskArgs.contract;
		if (contractAddress === "") {
			const C = await deployments.get('Contests');
			contractAddress = C.address;
		}
		const c = await ethers.getContractAt("Contests", contractAddress, signer);
		c.once("ContestFinished", (id: number, winner: string, reward: number) => {
			console.log("Event ContestFinished", id, winner, reward);
		});
		const tx = await c.finalizeContest(taskArgs.contestid);


		await tx.wait(3);
		console.log("tx:", tx);
	});

task("start-eval", "set eval data")
	.addOptionalParam("contract", "contract address", "", types.string)
	.addOptionalParam("contestid", "contest id", 1, types.int)
	.addOptionalParam("w", "perceptron input image width", 10, types.int)
    .addOptionalParam("h", "perceptron input image height", 10, types.int)
	.setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
		const { ethers, deployments, getNamedAccounts } = hre;
		const { modelMinter: signerAddress } = await getNamedAccounts();
		const signer = await ethers.getSigner(signerAddress);

		let contractAddress = taskArgs.contract;
		if (contractAddress === "") {
			const C = await deployments.get('Contests');
			contractAddress = C.address;
		}
		const c = await ethers.getContractAt("Contests", contractAddress, signer);

		const filenames = ["sample-images/artblock20/00-Friendship Bracelets/000.png", "sample-images/artblock20/01-Chromie Squiggle/001.png"];
		const resultClasses = [0, 1];
		let { w, h } = taskArgs;

		const pixelsLst = await Promise.all(filenames.map(async (filename: string) => {
			const img = fs.readFileSync(filename);	              
	        const imgBuffer = await sharp(img).removeAlpha().resize(w, h).raw().toBuffer();
	        const imgArray = [...imgBuffer];
	        const pixels = imgArray.map((b: any) => 
	            ethers.BigNumber.from(b).mul(ethers.BigNumber.from(10).pow(ethers.BigNumber.from(18))));
	        return pixels;
	    }));
	    console.log("pixelsLst:", pixelsLst.length, pixelsLst[0].length);
	    // return;

		const tx = await c.setEvaluateData(taskArgs.contestid, pixelsLst, resultClasses);
		await tx.wait();
		console.log("tx:", tx);
	});

task("grade-model", "")
	.addOptionalParam("contract", "contract address", "", types.string)
	.addOptionalParam("contestid", "contest id", 1, types.int)
	.addOptionalParam("modelid", "model id", 1, types.int)
	.setAction(async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
		const { ethers, deployments, getNamedAccounts } = hre;
		const { modelMinter: signerAddress } = await getNamedAccounts();
		const signer = await ethers.getSigner(signerAddress);

		let contractAddress = taskArgs.contract;
		if (contractAddress === "") {
			const C = await deployments.get('Contests');
			contractAddress = C.address;
		}
		const c = await ethers.getContractAt("Contests", contractAddress, signer);
		c.once("ModelGraded", (id: number, modelid: number, score: number) => {
			console.log("Event ModelGraded", id, modelid, score);
		});
		const tx = await c.gradeModel(taskArgs.contestid, taskArgs.modelid);
		await tx.wait(3);
		console.log("tx:", tx);
	});

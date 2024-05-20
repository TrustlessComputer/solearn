// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/WorkerHub.sol";

contract WorkHubTest is Test {
    WorkerHub workerHub;
    address public constant ADMIN_ADDR = address(10);
    address public constant Miner1 = address(101);
    address public constant Miner2 = address(102);
    address public constant Miner3 = address(103);
    address public constant ModelAddr = address(1);


    function setUp() public {
        workerHub = new WorkerHub();

        vm.startPrank(ADMIN_ADDR);
        workerHub.initialize(
            ADMIN_ADDR,
            10,
            1e18,
            1e18,
            1,
            1,
            10,
            9000, // 90%
            1229997 * 1e16, // reward 1 worker in one year
            21 days,
            0,
            0
        );

        workerHub.registerModel(ModelAddr, 1, 1e18);
        vm.stopPrank();
        // Sunday, May 19, 2024 4:14:11 PM
        vm.warp(1716135251);
    }

    function testRewards() public {
        vm.deal(Miner1, 2e18);
        vm.deal(Miner2, 2e18);
        vm.deal(Miner3, 2e18);
        assertEq(workerHub.lastBlock(), 1);
        // init block height
        vm.roll(11);
        vm.startPrank(Miner1);
        workerHub.registerMiner{value: 1e18}(1);
        workerHub.joinForMinting();
        vm.stopPrank();

        vm.startPrank(Miner2);
        workerHub.registerMiner{value: 1e18}(1);
        workerHub.joinForMinting();
        vm.stopPrank();

        vm.startPrank(Miner3);
        workerHub.registerMiner{value: 1e18}(1);
        workerHub.joinForMinting();
        vm.stopPrank();

        assertEq(workerHub.lastBlock(), 11);
        assertEq(workerHub.currentEpoch(), 1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);
        (uint256 pefReward, uint256 epochReward, uint256 totalTaskCompleted, uint256 totalMiner) = workerHub.rewardInEpoch(0);
        //        assertEq(totalMiner, 3);
        assertEq(pefReward, 0);
        assertEq(epochReward, 0);
        assertEq(totalTaskCompleted, 0);
        assertEq(workerHub.rewardPerEpoch(), 12299970000000000000000);

        // create some data for 2 epochs sequence
        vm.roll(31);
        workerHub.rewardToClaim(ADMIN_ADDR);
        ( pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 0);
        assertEq(epochReward, 23401769406392694);

        ( pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 0);
        assertEq(epochReward, 23401769406392694);

        assertEq(workerHub.rewardToClaim(Miner1), 15601179604261796);
        assertEq(workerHub.rewardToClaim(Miner2), 15601179604261796);
        assertEq(workerHub.rewardToClaim(Miner3), 15601179604261796);

        // setup task totalTaskCompleted
        // epoch 1

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 0);
        // assertEq(totalTaskCompleted, 10);

        // epoch 2

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 0);
        assertEq(totalTaskCompleted, 0);

        assertEq(workerHub.rewardToClaim(Miner1), 15601179604261796);
        assertEq(workerHub.rewardToClaim(Miner2), 15601179604261796);
        assertEq(workerHub.rewardToClaim(Miner3), 15601179604261796);

        vm.deal(address(workerHub), address(workerHub).balance + 2e18);
        // claim reward
        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 15601179604261796 + 1e18);
        assertEq(Miner2.balance, 15601179604261796 + 1e18);
        assertEq(Miner3.balance, 15601179604261796 + 1e18);

        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);

        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 15601179604261796 + 1e18);
        assertEq(Miner2.balance, 15601179604261796 + 1e18);
        assertEq(Miner3.balance, 15601179604261796 + 1e18);

        // test miner request unstake
        vm.startPrank(Miner1);
        workerHub.unregisterMiner();
        vm.warp(block.timestamp + 21 days);
        workerHub.unstakeForMiner();
        assertEq(Miner1.balance, 15601179604261796 + 2e18);

        assertEq(workerHub.multiplier(Miner1), 1e4);

        vm.roll(51);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 15601179604261796 + 2e18);
        workerHub.registerMiner{value: 1e18}(1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 15601179604261796 + 2e18 - 1e18);
        workerHub.unregisterMiner();
        vm.warp(block.timestamp + 21 days);
        workerHub.unstakeForMiner();
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 15601179604261796 + 2e18);
        workerHub.registerMiner{value: 1e18}(1);
        vm.roll(55);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 15601179604261796 + 2e18 - 1e18);
        vm.roll(61);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 15601179604261796 + 2e18 - 1e18);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.multiplier(Miner1), 1e4);
        // test case miner active then unregis but no claim reward
        workerHub.joinForMinting();

        // assertEq(workerHub.test(Miner1), block.timestamp);
        assertEq(workerHub.multiplier(Miner1), 1e4);

        vm.roll(71);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898);
        vm.roll(81);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);
        workerHub.unregisterMiner();
        vm.warp(block.timestamp + 21 days);
        workerHub.unstakeForMiner();
        assertEq(Miner1.balance, 15601179604261796 + 2e18);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);

        // assertEq(workerHub.test(Miner1) + 21 days, block.timestamp);

        vm.roll(91);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);
        workerHub.registerMiner{value: 1e18}(1);
        workerHub.joinForMinting();

        // assertEq(workerHub.test(Miner1), block.timestamp);

        vm.roll(101);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 3);
        // assertEq(workerHub.test(Miner1), block.timestamp);

        // claim reward
        workerHub.claimReward(Miner1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(Miner1.balance, 15601179604261796 + 2e18 - 1e18 + 7800589802130898 * 3);
        vm.roll(109);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        vm.stopPrank();

        // test boost reward
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        // add 2 epochs
        vm.roll(121);
        assertEq(workerHub.multiplier(Miner2), 11000);
        assertEq(workerHub.multiplier(Miner1), 1e4);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);
        // assertEq(workerHub.test(Miner1), block.timestamp);
        vm.warp(block.timestamp + 30 days);
        uint boostReward = 7800589802130898 * 2 * 10500 / uint256(1e4);
        assertEq(workerHub.rewardToClaim(Miner1), boostReward);

        vm.warp(block.timestamp + 30 days);
        boostReward = 7800589802130898 * 2 * 11000 / uint256(1e4);
        assertEq(workerHub.rewardToClaim(Miner1), boostReward);

        vm.warp(block.timestamp + 365 days);
        boostReward = 7800589802130898 * 2 * 16000 / uint256(1e4);
        assertEq(workerHub.rewardToClaim(Miner1), boostReward);

        workerHub.claimReward(Miner1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);

        // unregis reset boost
        vm.startPrank(Miner1);
        workerHub.unregisterMiner();
        assertEq(workerHub.multiplier(Miner1), 1e4);

        assertEq(workerHub.getNOMiner(), 2);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/WorkerHub.sol";
import "../contracts/tests/TestToken.sol";
import "forge-std/console.sol";

contract WorkHubTest is Test {
    WorkerHub workerHub;
    TestToken token;
    
    address public constant ADMIN_ADDR = address(0x10);
    address public constant Miner1 = address(0x101);
    address public constant Miner2 = address(0x102);
    address public constant Miner3 = address(0x103);
    address public constant ModelAddr = address(0x1);

    function setUp() public {
        workerHub = new WorkerHub();
        token = new TestToken();

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
            0,
            address(token)
        );
        workerHub.registerModel(ModelAddr, 1, 1e18);

        token.initialize("TestToken", "TEST");
        address[] memory minerAddresses = new address[](3);
        minerAddresses[0] = Miner1;
        minerAddresses[1] = Miner2;
        minerAddresses[2] = Miner3;
        for(uint i = 0; i < minerAddresses.length; ++i) {
            vm.startPrank(minerAddresses[i]);
            token.approve(address(workerHub), 100e18);
            vm.stopPrank();
        }

        vm.stopPrank();
        // Sunday, May 19, 2024 4:14:11 PM
        vm.warp(1716135251);
    }

    function testRewards() public {
        address[] memory minerAddresses = new address[](3);
        minerAddresses[0] = Miner1;
        minerAddresses[1] = Miner2;
        minerAddresses[2] = Miner3;
        token.mintFor(minerAddresses, 2e18);

        assertEq(workerHub.lastBlock(), 1);
        // init block height
        vm.roll(11);
        vm.startPrank(Miner1);
        workerHub.registerMiner(1, 1e18);
        workerHub.joinForMinting();
        vm.stopPrank();

        vm.startPrank(Miner2);
        workerHub.registerMiner(1, 1e18);
        workerHub.joinForMinting();
        vm.stopPrank();

        vm.startPrank(Miner3);
        workerHub.registerMiner(1, 1e18);
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

        token.mintFor(address(workerHub), 2e18);
        // claim reward
        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(token.balanceOf(Miner1), 15601179604261796 + 1e18);
        assertEq(token.balanceOf(Miner2), 15601179604261796 + 1e18);
        assertEq(token.balanceOf(Miner3), 15601179604261796 + 1e18);

        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);

        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(token.balanceOf(Miner1), 15601179604261796 + 1e18);
        assertEq(token.balanceOf(Miner2), 15601179604261796 + 1e18);
        assertEq(token.balanceOf(Miner3), 15601179604261796 + 1e18);

        // test miner request unstake
        vm.startPrank(Miner1);
        workerHub.unregisterMiner();
        vm.warp(vm.getBlockTimestamp() + 21 days);
        workerHub.unstakeForMiner();
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18);

        assertEq(workerHub.multiplier(Miner1), 1e4);

        vm.roll(51);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18);
        workerHub.registerMiner(1, 1e18);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18 - 1e18);
        workerHub.unregisterMiner();
        vm.warp(vm.getBlockTimestamp() + 21 days);
        workerHub.unstakeForMiner();
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18);
        workerHub.registerMiner(1, 1e18);
        vm.roll(55);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18 - 1e18);
        vm.roll(61);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18 - 1e18);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.multiplier(Miner1), 1e4);
        // test case miner active then unregis but no claim reward
        workerHub.joinForMinting();

        // assertEq(workerHub.test(Miner1), vm.getBlockTimestamp());
        assertEq(workerHub.multiplier(Miner1), 1e4);

        vm.roll(71);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898);
        vm.roll(81);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);
        workerHub.unregisterMiner();
        vm.warp(vm.getBlockTimestamp() + 21 days);
        workerHub.unstakeForMiner();
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);

        // assertEq(workerHub.test(Miner1) + 21 days, vm.getBlockTimestamp());

        vm.roll(91);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 2);
        workerHub.registerMiner(1, 1e18);
        workerHub.joinForMinting();

        // assertEq(workerHub.test(Miner1), vm.getBlockTimestamp());

        vm.roll(101);
        assertEq(workerHub.rewardToClaim(Miner1), 7800589802130898 * 3);
        // assertEq(workerHub.test(Miner1), vm.getBlockTimestamp());

        // claim reward
        workerHub.claimReward(Miner1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(token.balanceOf(Miner1), 15601179604261796 + 2e18 - 1e18 + 7800589802130898 * 3);
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
        // assertEq(workerHub.test(Miner1), vm.getBlockTimestamp());
        vm.warp(vm.getBlockTimestamp() + 30 days);
        uint boostReward = 7800589802130898 * 2 * 10500 / uint256(1e4);
        assertEq(workerHub.rewardToClaim(Miner1), boostReward);

        vm.warp(vm.getBlockTimestamp() + 30 days);
        boostReward = 7800589802130898 * 2 * 11000 / uint256(1e4);
        assertEq(workerHub.rewardToClaim(Miner1), boostReward);

        vm.warp(vm.getBlockTimestamp() + 365 days);
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

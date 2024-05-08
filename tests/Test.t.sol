// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/WorkerHub.sol";

contract Mockup is WorkerHub {

    function setMinerTaskCompleteInEpoch(address miner, uint epoch, uint totalCompleted) public {
        _updateEpoch();

        minterTaskCompleted[miner][epoch] = totalCompleted;
    }

    function setTotalTaskCompleteInEpoch(uint epoch, uint totalCompleted) public {
        _updateEpoch();

        rewardInEpoch[epoch].totalTaskCompleted = totalCompleted;
    }

}

contract WorkHubTest is Test {
    Mockup workerHub;
    address public constant ADMIN_ADDR = address(10);
    address public constant Miner1 = address(101);
    address public constant Miner2 = address(102);
    address public constant Miner3 = address(103);

    function setUp() public {
        workerHub = new Mockup();

        vm.prank(ADMIN_ADDR);
        workerHub.initialize(
            1e18,
            1e18,
            1,
            1,
            1,
            1,
            1,
            1,
            10,
            1e18,
            1 days,
            21 days
        );

        vm.prank(ADMIN_ADDR);
        workerHub.setNewRewardInEpoch(1e16);
    }

    function testRewards() public {
        vm.deal(Miner1, 2e18);
        vm.deal(Miner2, 2e18);
        vm.deal(Miner3, 2e18);

        // init block height
        vm.roll(10);
        vm.prank(Miner1);
        workerHub.registerMinter{value: 1e18}(1);

        vm.prank(Miner2);
        workerHub.registerMinter{value: 1e18}(1);

        vm.prank(Miner3);
        workerHub.registerMinter{value: 1e18}(1);

        assertEq(workerHub.currentEpoch(), 1);
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        assertEq(workerHub.getRewardToClaim(Miner2), 0);
        assertEq(workerHub.getRewardToClaim(Miner3), 0);
        (uint256 pefReward, uint256 epochReward, uint256 totalTaskCompleted) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 1e18);
        assertEq(totalTaskCompleted, 0);
        assertEq(workerHub.rewardPerEpoch(), 1e16);
        assertEq(workerHub.lastBlock(), 10);

        // create some data for 2 epochs sequence
        vm.roll(30);
        assertEq(workerHub.getRewardToClaim(Miner1), 20000000000000000);
        assertEq(workerHub.getRewardToClaim(Miner2), 20000000000000000);
        assertEq(workerHub.getRewardToClaim(Miner3), 20000000000000000);

        // setup task totalTaskCompleted
        // epoch 1
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 1, 6);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 1, 1);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 1, 3);
        workerHub.setTotalTaskCompleteInEpoch(1, 10);

        (pefReward, epochReward, totalTaskCompleted) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 1e18);
        assertEq(totalTaskCompleted, 10);

        // epoch 2
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 2, 3);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 2, 0);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 2, 7);
        workerHub.setTotalTaskCompleteInEpoch(2, 10);

        (pefReward, epochReward, totalTaskCompleted) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 1e18);
        assertEq(totalTaskCompleted, 10);

        assertEq(workerHub.getRewardToClaim(Miner1), 920000000000000000);
        assertEq(workerHub.getRewardToClaim(Miner2), 120000000000000000);
        assertEq(workerHub.getRewardToClaim(Miner3), 1020000000000000000);

        vm.deal(address(workerHub), address(workerHub).balance + 2e18);
        // claim reward
        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 920000000000000000 + 1e18);
        assertEq(Miner2.balance, 120000000000000000 + 1e18);
        assertEq(Miner3.balance, 1020000000000000000 + 1e18);

        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        assertEq(workerHub.getRewardToClaim(Miner2), 0);
        assertEq(workerHub.getRewardToClaim(Miner3), 0);

        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 920000000000000000 + 1e18);
        assertEq(Miner2.balance, 120000000000000000 + 1e18);
        assertEq(Miner3.balance, 1020000000000000000 + 1e18);

        // test miner request unstake
        vm.prank(Miner1);
        workerHub.unregisterMinter();
        assertEq(Miner1.balance, 920000000000000000 + 2e18);

        vm.startPrank(Miner1);
        vm.roll(50);
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 920000000000000000 + 2e18);
        workerHub.registerMinter{value: 1e18}(1);
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 920000000000000000 + 1e18);
        workerHub.unregisterMinter();
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 920000000000000000 + 2e18);
        workerHub.registerMinter{value: 1e18}(1);
        vm.roll(55);
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 920000000000000000 + 1e18);
        vm.roll(60);
        assertEq(workerHub.getRewardToClaim(Miner1), 1e16);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 920000000000000000 + 1e18 + 1e16);
        assertEq(workerHub.getRewardToClaim(Miner1), 0);
        vm.stopPrank();
    }
}
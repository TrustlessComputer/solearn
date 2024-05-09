// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/WorkerHub.sol";

contract Mockup is WorkerHub {

    function setMinerTaskCompleteInEpoch(address miner, uint epoch, uint totalCompleted) public {
        _updateEpoch();

        minerTaskCompleted[miner][epoch] = totalCompleted;
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
    address public constant ModelAddr = address(1);


    function setUp() public {
        workerHub = new Mockup();

        vm.startPrank(ADMIN_ADDR);
        workerHub.initialize(
            ADMIN_ADDR,
            10,
            1e18,
            1e18,
            1,
            1,
            10,
            1e18,
            21 days
        );
        workerHub.setNewRewardInEpoch(1e16);
        workerHub.registerModel(ModelAddr, 1, 1e18);
        vm.stopPrank();
    }

    function testRewards() public {
        vm.deal(Miner1, 2e18);
        vm.deal(Miner2, 2e18);
        vm.deal(Miner3, 2e18);
        assertEq(workerHub.lastBlock(), 1);
        // init block height
        vm.roll(11);
        vm.prank(Miner1);
        workerHub.registerMiner{value: 1e18}(1);

        vm.prank(Miner2);
        workerHub.registerMiner{value: 1e18}(1);

        vm.prank(Miner3);
        workerHub.registerMiner{value: 1e18}(1);

        assertEq(workerHub.lastBlock(), 11);
        assertEq(workerHub.currentEpoch(), 1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);
        (uint256 pefReward, uint256 epochReward, uint256 totalTaskCompleted, uint256 totalMiner) = workerHub.rewardInEpoch(1);
//        assertEq(totalMiner, 3);
        assertEq(pefReward, 1e18);
        assertEq(epochReward, 1e16);
        assertEq(totalTaskCompleted, 0);
        assertEq(workerHub.rewardPerEpoch(), 1e16);

        // create some data for 2 epochs sequence
        vm.roll(31);
        assertEq(workerHub.rewardToClaim(Miner1), 6666666666666666);
        assertEq(workerHub.rewardToClaim(Miner2), 6666666666666666);
        assertEq(workerHub.rewardToClaim(Miner3), 6666666666666666);

        // setup task totalTaskCompleted
        // epoch 1
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 1, 6);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 1, 1);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 1, 3);
        workerHub.setTotalTaskCompleteInEpoch(1, 10);

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 1e18);
        assertEq(totalTaskCompleted, 10);

        // epoch 2
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 2, 3);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 2, 0);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 2, 7);
        workerHub.setTotalTaskCompleteInEpoch(2, 10);

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 1e18);
        assertEq(totalTaskCompleted, 10);

        assertEq(workerHub.rewardToClaim(Miner1), 906666666666666666);
        assertEq(workerHub.rewardToClaim(Miner2), 106666666666666666);
        assertEq(workerHub.rewardToClaim(Miner3), 1006666666666666666);

        vm.deal(address(workerHub), address(workerHub).balance + 2e18);
        // claim reward
        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 906666666666666666 + 1e18);
        assertEq(Miner2.balance, 106666666666666666 + 1e18);
        assertEq(Miner3.balance, 1006666666666666666 + 1e18);

        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);

        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 906666666666666666 + 1e18);
        assertEq(Miner2.balance, 106666666666666666 + 1e18);
        assertEq(Miner3.balance, 1006666666666666666 + 1e18);

        // test miner request unstake
        vm.prank(Miner1);
        workerHub.unregisterMiner();
        assertEq(Miner1.balance, 906666666666666666 + 2e18);

        vm.startPrank(Miner1);
        vm.roll(51);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 906666666666666666 + 2e18);
        workerHub.registerMiner{value: 1e18}(1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 906666666666666666 + 1e18);
        workerHub.unregisterMiner();
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 906666666666666666 + 2e18);
        workerHub.registerMiner{value: 1e18}(1);
        vm.roll(55);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 906666666666666666 + 1e18);
        vm.roll(61);
        assertEq(workerHub.rewardToClaim(Miner1), 3333333333333333);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 906666666666666666 + 1e18 + 3333333333333333);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        vm.stopPrank();
    }
}

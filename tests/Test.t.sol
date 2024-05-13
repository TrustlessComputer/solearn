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
            9000, // 90%
            1229997 * 1e16, // reward 1 worker in one year
            21 days
        );
//        workerHub.setNewRewardInEpoch(1e16);
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
        assertEq(pefReward, 21061592465753424);
        assertEq(epochReward, 2340176940639270);

        ( pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 21061592465753424);
        assertEq(epochReward, 2340176940639270);

        assertEq(workerHub.rewardToClaim(Miner1), 1560117960426180);
        assertEq(workerHub.rewardToClaim(Miner2), 1560117960426180);
        assertEq(workerHub.rewardToClaim(Miner3), 1560117960426180);

        // setup task totalTaskCompleted
        // epoch 1
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 1, 6);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 1, 1);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 1, 3);
        workerHub.setTotalTaskCompleteInEpoch(1, 10);

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(1);
        assertEq(pefReward, 21061592465753424);
        assertEq(totalTaskCompleted, 10);

        // epoch 2
        workerHub.setMinerTaskCompleteInEpoch(Miner1, 2, 3);
        workerHub.setMinerTaskCompleteInEpoch(Miner2, 2, 0);
        workerHub.setMinerTaskCompleteInEpoch(Miner3, 2, 7);
        workerHub.setTotalTaskCompleteInEpoch(2, 10);

        (pefReward, epochReward, totalTaskCompleted, totalMiner) = workerHub.rewardInEpoch(2);
        assertEq(pefReward, 21061592465753424);
        assertEq(totalTaskCompleted, 10);

        assertEq(workerHub.rewardToClaim(Miner1), 20515551179604261);
        assertEq(workerHub.rewardToClaim(Miner2), 3666277207001522);
        assertEq(workerHub.rewardToClaim(Miner3), 22621710426179603);

        vm.deal(address(workerHub), address(workerHub).balance + 2e18);
        // claim reward
        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 20515551179604261 + 1e18);
        assertEq(Miner2.balance, 3666277207001522 + 1e18);
        assertEq(Miner3.balance, 22621710426179603 + 1e18);

        assertEq(workerHub.rewardToClaim(Miner1), 0);
        assertEq(workerHub.rewardToClaim(Miner2), 0);
        assertEq(workerHub.rewardToClaim(Miner3), 0);

        workerHub.claimReward(Miner1);
        workerHub.claimReward(Miner2);
        workerHub.claimReward(Miner3);

        assertEq(Miner1.balance, 20515551179604261 + 1e18);
        assertEq(Miner2.balance, 3666277207001522 + 1e18);
        assertEq(Miner3.balance, 22621710426179603 + 1e18);

        // test miner request unstake
        vm.startPrank(Miner1);
        workerHub.unregisterMiner();
        vm.warp(block.timestamp + 21 days);
        workerHub.unstakeForMiner();
        assertEq(Miner1.balance, 2020515551179604261);

        vm.roll(51);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 2020515551179604261);
        workerHub.registerMiner{value: 1e18}(1);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 2020515551179604261 - 1e18);
        workerHub.unregisterMiner();
        vm.warp(block.timestamp + 21 days);
        workerHub.unstakeForMiner();
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 2020515551179604261);
        workerHub.registerMiner{value: 1e18}(1);
        vm.roll(55);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 2020515551179604261 - 1e18);
        vm.roll(61);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        workerHub.claimReward(Miner1);
        assertEq(Miner1.balance, 2020515551179604261 - 1e18);
        assertEq(workerHub.rewardToClaim(Miner1), 0);
        vm.stopPrank();
    }
}

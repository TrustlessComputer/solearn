// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Random} from "../lib/Random.sol";
import {Set} from "../lib/Set.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    Random.Randomizer internal randomizer;

    mapping(address => Model) public models;
    mapping(address => Worker) public miners;
    mapping(address => Worker) public validators;

    mapping(address => Set.AddressSet) internal minerAddressesByModel;
    mapping(address => Set.AddressSet) internal validatorAddressesByModel;

    Set.AddressSet internal modelAddresses;
    Set.AddressSet internal minerAddresses;
    Set.AddressSet internal validatorAddresses;

    mapping(address => UnstakeRequest) public minerUnstakeRequests;
    mapping(address => UnstakeRequest) public validatorUnstakeRequests;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;

    uint256 public assignmentNumber;
    mapping(uint256 => Assignment) public assignments;
    mapping(address => Set.Uint256Set) internal assignmentsByMiner;
    mapping(uint256 => Set.Uint256Set) internal assignmentsByInference;

    mapping(address => mapping(uint256 => bool)) public validatorDisputed;

    // mapping total task completed in epoch and reward per epoch
    // epoch index => total reward
    mapping(uint256 => MinerEpochState) public rewardInEpoch;

    // mapping detail miner completed how many request
    // total task completed in epoch
    // miner => epoch => total task completed
    mapping(address => mapping(uint256 => uint256)) internal minerTaskCompleted;

    uint256 public minerMinimumStake;
    uint256 public validatorMinimumStake;
    address public treasury;
    uint16 public feePercentage;
    uint40 public miningTimeLimit;
    uint40 public validatingTimeLimit;
    uint40 public disputingTimeLimit;
    uint40 public penaltyDuration;
    uint40 public unstakeDelayTime;
    uint8 public minerRequirement;

    uint16 public maximumTier;
    uint16 public disqualificationPercentage;

    // reward purpose
    uint40 public currentEpoch;
    uint256 public blocksPerEpoch;
    uint256 public lastBlock;
    uint256 internal rewardPerEpochBasedOnPerf; // percentage for workers completed task
    uint256 public rewardPerEpoch; // 12299.97 reward EAI for 1 worker per year

    // Tx Fee
    uint16 public finePercentage;

    // mapping tracking reward
    mapping(address => uint256) internal minerRewards;
    // tracking time miner join the network to
    // determine multiplier value
    mapping(address => Boost) internal boost;

    uint256[97] private __gap;
}

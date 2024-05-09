// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Heap} from "../lib/heap/Heap.sol";
import {Set} from "../lib/Set.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    uint256 public mintingAssignmentNumber;
    mapping(uint256 => Assignment) internal mintingAssignments;

    uint256 public modelNumber;
    mapping(address => Model) public models;
    uint256 public minterNumber;
    mapping(address => Worker) public minters;
    mapping(address => Worker) public validators;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;

    Set.AddressSet internal modelAddresses;
    Set.AddressSet internal minterAddresses;
    Set.AddressSet internal validatorAddresses;

    mapping(address => Set.AddressSet) internal minterAddressesByModel;
    mapping(address => Set.AddressSet) internal validatorAddressesByModel;

    uint256 public minterMinimumStake;
    uint256 public validatorMinimumStake;
    uint40 public mintingTimeLimit;
    uint40 public validatingTimeLimit;
    uint40 public disputingTimeLimit;
    uint40 public penaltyDuration;
    uint40 public unstakeDelayTime;
    uint8 public minterRequirement;

    uint16 public maximumTier;
    uint16 public disqualificationPercentage;

    // validator mapping validator => assigment id => boolean
    mapping(address => mapping(uint256 => bool)) public validatorDisputed;

    // reward purpose
    uint256 public blocksPerEpoch;
    uint96 public currentEpoch;
    uint256 public lastBlock;
    uint256 public rewardPerEpochBasedOnPerf;
    uint256 public rewardPerEpoch;

    // mapping total task completed in epoch and reward per epoch
    // epoch index => total reward
    mapping(uint256 => MinterEpochState) public rewardInEpoch;

    // mapping detail minter completed how many request
    // total task completed in epoch
    // minter => epoch => total task completed
    mapping(address => mapping(uint256 => uint256)) public minterTaskCompleted;

    uint256[50] private __gap;
}

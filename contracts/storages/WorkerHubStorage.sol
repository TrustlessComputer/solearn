// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Heap} from "../lib/heap/Heap.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    uint256 public mintingAssignmentsFront;
    uint256 public mintingAssignmentsRear;
    mapping(uint256 => Assignment) internal mintingAssignments;

    uint256 public validatingAssignmentsFront;
    uint256 public validatingAssignmentsRear;
    mapping(uint256 => Assignment) internal validatingAssignments;

    uint256 public modelNumber;
    mapping(address => Model) public models;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;

    uint256 public taskNumber;
    mapping(uint256 => Task) internal tasks;
    Heap.Uint256Heap internal mintingTaskQueue;
    Heap.Uint256Heap internal validatingTaskQueue;

    mapping(address => Worker) public minters;
    mapping(address => Worker) public validators;
    mapping(uint256 => Heap.AddressHeap) internal minterQueues;
    mapping(uint256 => Heap.AddressHeap) internal validatorQueues;

    uint256 public minterMinimumStake;
    uint256 public validatorMinimumStake;
    uint40 public mintingTimeLimit;
    uint40 public validatingTimeLimit;
    uint8 public minterRequirement;
    uint8 public validatorRequirement;

    uint16 public maximumTier;

    // validator mapping validator => assigment id => boolean
    mapping(address => mapping(uint256 => bool)) public validatorDisputed;

    // reward purpose
    uint256 public blocksPerEpoch;
    uint256 public currentEpoch;
    uint256 public lastBlock;
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

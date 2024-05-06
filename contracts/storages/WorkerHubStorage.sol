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

    uint256[50] private __gap;
}

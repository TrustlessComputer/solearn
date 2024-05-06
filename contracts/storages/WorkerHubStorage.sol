// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Heap} from "../lib/heap/Heap.sol";
import {Set} from "../lib/set/Set.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    uint256 public mintingAssignmentNumber;
    mapping(address => Set.Uint256Set) internal assignmentsByMinters;
    mapping(uint256 => Assignment) public mintingAssignments;

    uint256 public validatingAssignmentNumber;
    mapping(address => Set.Uint256Set) internal assignmentsByValidators;
    mapping(uint256 => Assignment) public validatingAssignments;

    uint256 public modelNumber;
    mapping(address => Model) public models;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;

    mapping(address => Worker) public minters;
    mapping(address => Worker) public validators;

    Set.AddressSet internal minterAddresses;
    Set.AddressSet internal validatorAddresses;

    uint256 public minterPivot;
    uint256 public validatorPivot;
    uint256 public minterMinimumStake;
    uint256 public validatorMinimumStake;
    uint40 public mintingTimeLimit;
    uint40 public validatingTimeLimit;
    uint8 public minterRequirement;
    uint8 public validatorRequirement;

    uint16 public maximumTier;

    uint256[50] private __gap;
}

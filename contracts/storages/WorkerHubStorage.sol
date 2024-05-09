// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Random} from "../lib/Random.sol";
import {Set} from "../lib/Set.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    Random.Randomizer internal randomizer;

    mapping(address => Model) public models;
    mapping(address => Worker) public minters;
    mapping(address => Worker) public validators;

    mapping(address => Set.AddressSet) internal minterAddressesByModel;
    mapping(address => Set.AddressSet) internal validatorAddressesByModel;

    Set.AddressSet internal modelAddresses;
    Set.AddressSet internal minterAddresses;
    Set.AddressSet internal validatorAddresses;

    mapping(address => UnstakeRequest) public minterUnstakeRequests;
    mapping(address => UnstakeRequest) public validatorUnstakeRequests;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;

    uint256 public assignmentNumber;
    mapping(uint256 => Assignment) internal assignments;
    mapping(address => Set.Uint256Set) internal assignmentsByMinter;
    mapping(uint256 => Set.Uint256Set) internal assignmentsByInference;

    mapping(address => mapping(uint256 => bool)) public validatorDisputed;

    // mapping total task completed in epoch and reward per epoch
    // epoch index => total reward
    mapping(uint256 => MinterEpochState) public rewardInEpoch;

    // mapping detail minter completed how many request
    // total task completed in epoch
    // minter => epoch => total task completed
    mapping(address => mapping(uint256 => uint256)) public minterTaskCompleted;

    uint256 public minterMinimumStake;
    uint256 public validatorMinimumStake;
    address public treasury;
    uint16 public feePercentage;
    uint40 public mintingTimeLimit;
    uint40 public validatingTimeLimit;
    uint40 public disputingTimeLimit;
    uint40 public penaltyDuration;
    uint40 public unstakeDelayTime;
    uint8 public minterRequirement;

    uint16 public maximumTier;
    uint16 public disqualificationPercentage;

    // reward purpose
    uint40 public currentEpoch;
    uint256 public blocksPerEpoch;
    uint256 public lastBlock;
    uint256 public rewardPerEpochBasedOnPerf;
    uint256 public rewardPerEpoch;

    uint256[100] private __gap;
}

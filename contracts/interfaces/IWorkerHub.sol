// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHeapComparator} from "../lib/heap/IHeapComparator.sol";

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable, IHeapComparator {
    struct Model {
        uint256 modelId;
        uint256 minimumFee;
        uint32 tier;
    }

    struct Worker {
        uint256 stake;
        uint256 currentTaskId;
        uint256 commission;
        uint16 tier;
    }

    struct Assignment {
        uint256 inferenceId;
        address worker;
        uint40 expiredAt;
        bool accomplished;
    }

    struct Task {
        uint256 inferenceId;
        uint256 value;
        uint8 workerRequirement;
    }

    struct Output {
        bytes data;
        uint256 validationSubmissions;
        address minter;
        uint8 approval;
    }

    struct Inference {
        address[] minters;
        address[] validators;
        Output[] outputs;
        address modelAddress;
        uint256 modelId;
        uint256 value;
        bytes input;
        address creator;
    }

    event ModelRegistration(
        address indexed model,
        uint256 indexed modelId,
        uint16 indexed tier,
        uint256 minimumFee
    );
    event ModelUnregistration(address indexed model);

    event MinterExtraStake(address indexed minter, uint256 value);
    event MinterRegistration(
        address indexed minter,
        uint16 indexed tier,
        uint256 value
    );
    event MinterUnregistration(address indexed minter);

    event ValidatorExtraStake(address indexed validator, uint256 value);
    event ValidatorRegistration(
        address indexed validator,
        uint16 indexed tier,
        uint256 value
    );
    event ValidatorUnregistration(address indexed validator);

    event NewInference(
        uint256 indexed inferenceId,
        address indexed creator,
        uint256 value
    );

    error AlreadyRegistered();
    error NotRegistered();
    error Unauthorized();

    error InvalidModel();
    error InvalidTier();

    error FeeTooLow();
    error StakeTooLow();

    error MintingSessionNotEnded();
    error ValidatingSessionNotEnded();
}

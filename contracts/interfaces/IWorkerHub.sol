// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHeapComparator} from "../lib/heap/IHeapComparator.sol";

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable, IHeapComparator {
    enum InferStatus {
        None,
        Solving,
        Disputed,
        Solved,
        Killed
    }

    struct MinterEpochState {
        uint256 totalReward;
        uint96 totalTaskCompleted;
    }

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
        uint40 activeTime;
        uint96 lastClaimedEpoch;
    }

    struct Assignment {
        uint256 inferenceId;
        uint256 validationSubmissions;
        address worker;
        uint8 disapproval; // 1 / 3 total val
        bytes data;
    }

    struct Inference {
        uint256[] assignments; // assignment ids solution submitter
        uint256 totalValidator;
        address modelAddress;
        uint256 modelId;
        uint256 value;
        bytes input;
        address disputeAddress; // the first validator submit dispute request => punishment
        uint40 expiredAt;
        uint8 firstSubmitterIndex;
        InferStatus status;
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
        uint256 value,
        uint256 activeTime
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

    event SubmitSolution(
        address indexed _minter,
        uint256 indexed _assigmentId
    );

    event DisputeInfer(
        address indexed _validator,
        uint256 indexed _assigmentId
    );

    event InferStatusUpdated(
        uint256 indexed _inferId,
        InferStatus _newStatus
    );

    event WithdrawUnstaked(
        address indexed _validator,
        uint256 _amount
    );

    event ClaimReward(
        address indexed _minter,
        uint256 _amount
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

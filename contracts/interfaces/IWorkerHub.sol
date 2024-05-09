// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable {
    enum InferenceStatus {
        Nil,
        Solving,
        Disputing,
        Solved,
        Killed
    }

    struct MinterEpochState {
        uint256 perfReward;
        uint256 epochReward;
        uint256 totalTaskCompleted;
        uint256 totalMinter;
    }

    struct Model {
        uint256 minimumFee;
        uint32 tier;
    }

    struct Worker {
        uint256 stake;
        uint256 commitment;
        address modelAddress;
        uint40 lastClaimedEpoch;
        uint40 activeTime;
        uint16 tier;
    }

    struct WorkerInfo {
        address workerAddress;
        uint256 stake;
        uint256 commitment;
        address modelAddress;
        uint40 lastClaimedEpoch;
        uint40 activeTime;
        uint16 tier;
    }

    struct Assignment {
        uint256 inferenceId;
        bytes output;
        address worker;
        uint8 disapprovalCount;
    }

    struct AssignmentInfo {
        uint256 assignmentId;
        uint256 inferenceId;
        address modelAddress;
        bytes input;
        uint40 expiredAt;
    }

    struct Inference {
        uint256[] assignments;
        bytes input;
        uint256 value;
        address disputingAddress;
        address modelAddress;
        uint40 expiredAt;
        uint8 firstSubmissionId;
        InferenceStatus status;
        address creator;
    }

    struct InferenceInfo {
        uint256 inferenceId;
        bytes input;
        bytes output;
        uint256 value;
        address disputingAddress;
        address modelAddress;
        uint40 expiredAt;
        InferenceStatus status;
        address creator;
    }

    struct UnstakeRequest {
        uint256 stake;
        uint40 unlockAt;
    }

    event ModelRegistration(
        address indexed model,
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
    event InferenceDisputation(address indexed validator, uint256 indexed assigmentId);
    event InferenceStatusUpdate(uint256 indexed inferenceId, InferenceStatus newStatus);

    event NewAssignment(
        uint256 indexed assignmentId,
        uint256 indexed inferenceId,
        address indexed minter,
        uint40 expiredAt
    );
    event SolutionSubmission(address indexed minter, uint256 indexed assigmentId);

    event MinterUnstake(address indexed minter, uint256 stake);
    event ValidatorUnstake(address indexed validator, uint256 stake);

    event RewardClaim(address indexed worker, uint256 value);

    event RewardPerEpoch(uint256 oldReward, uint256 newReward);
    event RewardPerEpochBasedOnPerf(uint256 oldReward, uint256 newReward);
    event BlocksPerEpoch(uint256 oldBlocks, uint256 newBlocks);

    error AlreadyRegistered();
    error AlreadySubmitted();
    error NotRegistered();
    error Unauthorized();
    error StillBeingLocked();

    error InvalidBlockValue();
    error InvalidTier();

    error FeeTooLow();
    error StakeTooLow();
    error NullStake();

    error MintingSessionNotEnded();
    error ValidatingSessionNotEnded();

}

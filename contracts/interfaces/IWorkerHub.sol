// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable {
    enum InferenceStatus {
        Nil,
        Solving,
        Disputing,
        Voting,
        Solved,
        Killed
    }

    struct MinerEpochState {
        uint256 perfReward;
        uint256 epochReward;
        uint256 totalTaskCompleted;
        uint256 totalMiner;
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
        uint256 value;
        bytes input;
        address modelAddress;
        address creator;
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

    struct DisputedInfer {
        uint16 totalValidator;
        bool isValid;
        uint40 validatingExpireAt;
        uint40 disputingExpireAt;
    }

    struct Ballot {
        uint256 assignmentId;
        bool result;
    }

    struct UnstakeRequest {
        uint256 stake;
        uint40 unlockAt;
    }

    struct Boost {
        uint40 minerTimestamp;
        uint40 validatorTimestamp;
        uint48 reserved1;
        uint128 reserved2;
    }

    event MiningTimeLimitUpdate(uint40 newValue);

    event ModelRegistration(
        address indexed model,
        uint16 indexed tier,
        uint256 minimumFee
    );
    event ModelUnregistration(address indexed model);
    event ModelTierUpdate(address indexed model, uint32 tier);
    event ModelMinimumFeeUpdate(address indexed model, uint256 minimumFee);

    event MinerExtraStake(address indexed miner, uint256 value);
    event MinerRegistration(
        address indexed miner,
        uint16 indexed tier,
        uint256 value
    );
    event MinerUnregistration(address indexed miner);

    event ValidatorExtraStake(address indexed validator, uint256 value);
    event ValidatorRegistration(
        address indexed validator,
        uint16 indexed tier,
        uint256 value
    );
    event ValidatorUnregistration(address indexed validator);

    event NewInference(
        uint256 indexed inferenceId,
        address indexed model,
        address indexed creator,
        uint256 value
    );
    event InferenceDisputation(address indexed validator, uint256 indexed assigmentId);
    event InferenceStatusUpdate(uint256 indexed inferenceId, InferenceStatus newStatus);

    event NewAssignment(
        uint256 indexed assignmentId,
        uint256 indexed inferenceId,
        address indexed miner,
        uint40 expiredAt
    );
    event SolutionSubmission(address indexed miner, uint256 indexed assigmentId);
    event TransferFee(
        address indexed miner,
        uint256 mingingFee,
        address indexed treasury,
        uint256 protocolFee
    );

    event TopUpInfer(
        uint256 indexed inferenceId,
        address indexed creator,
        uint256 value
    );

    event MinerUnstake(address indexed miner, uint256 stake);
    event MinerJoin(address indexed miner);
    event ValidatorUnstake(address indexed validator, uint256 stake);
    event ValidatorJoin(address indexed validator);

    event RewardClaim(address indexed worker, uint256 value);

    event RewardPerEpoch(uint256 oldReward, uint256 newReward);
    event BlocksPerEpoch(uint256 oldBlocks, uint256 newBlocks);
    event UnstakeDelayTime(uint256 oldDelayTime, uint256 newDelayTime);
    event Restake(address indexed miner, uint256 restake, address indexed model);

    event PenaltyDurationUpdated(uint40 oldDuration, uint40 newDuration);
    event FinePercentageUpdated(uint16 oldPercent, uint16 newPercent);
    
    event MinerDeactivated(address indexed miner, address indexed modelAddress, uint40 activeTime);
    event FraudulentMinerPenalized(address indexed miner, address indexed modelAddress, address indexed treasury, uint256 fine);
    event ValidatorDeactivated(address indexed validator, address indexed modelAddress, uint40 activeTime);
    event FraudulentValidatorPenalized(address indexed validator, address indexed modelAddress, address indexed treasury,  uint256 fine);
    event DisputeInference(address indexed caller, uint256 indexed inferId, uint40 now, uint40 validateExpireTimestamp, uint40 disputeExpiredTimestamp);
    event NoDisputeInference(address indexed caller, uint256 indexed inferId, uint40 now, uint256 value);
    event DisputeUpvote(address indexed caller, uint256 indexed inferId, uint40 now);
    event DisputeResolving(uint256 indexed inferId, address indexed modelAddress, bool status);

    error AlreadyRegistered();
    error AlreadySubmitted();
    error NotRegistered();
    error NotEnoughMiners();
    error Unauthorized();
    error StillBeingLocked();

    error InvalidBlockValue();
    error InvalidModel();
    error InvalidTier();
    error InvalidInferenceStatus();

    error FeeTooLow();
    error StakeTooLow();
    error NullStake();

    error MiningSessionNotEnded();
    error ValidatingSessionNotEnded();
    error MiningSessionEnded();

    error InferMustBeSolvingState();
    error ZeroValue();
    error InvalidValidator();
    error InvalidMiner();

    error InferenceAlreadyDisputed();
    error InferenceNotDisputed();

    error PrematureValidate();
    error ValidateTimeout();
    error PrematureDispute();
    error DisputeTimeout();

    error ValidatorVoteExists();
    error SubmissionsEmpty();
    error LoneSubmissionNoDispute();
    error BallotEmpty();

    error MinerInDeactivationTime();
    error ValidatorInDeactivationTime();

}

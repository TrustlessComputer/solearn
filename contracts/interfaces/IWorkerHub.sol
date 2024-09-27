// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable {
    enum InferenceStatus {
        Nil,
        Solving,
        Commit,
        Reveal,
        FinalizedState,
        Processed,
        Killed
    }

    enum AssignmentRole {
        Nil,
        Validating,
        Mining
    }

    enum Vote {
        Nil,
        Disapproval,
        Approval
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
        bytes32 commitment;
        bytes32 digest; // keccak256(output)
        uint40 revealNonce;
        address worker;
        AssignmentRole role;
        Vote vote;
        bytes output;
    }

    struct AssignmentInfo {
        uint256 assignmentId;
        uint256 inferenceId;
        uint256 value;
        bytes input;
        address modelAddress;
        address creator;
        uint40 submitTimeout;
        uint40 commitTimeout;
        uint40 revealTimeout;
    }

    struct Inference {
        uint256[] assignments;
        bytes input;
        uint256 value;
        uint256 systemFee;
        address modelAddress;
        // uint40 expiredAt;
        uint40 submitTimeout; // limit time to capture the miner role and submit the solution
        uint40 commitTimeout;
        uint40 revealTimeout;
        uint8 firstSubmissionId;
        InferenceStatus status;
        address creator;
        address processedMiner;
    }

    struct VotingInfo {
        uint8 totalCommit;
        uint8 totalReveal;
    }

    struct InferenceInfo {
        uint256 inferenceId;
        bytes input;
        bytes output;
        uint256 value;
        address modelAddress;
        uint40 expiredAt;
        InferenceStatus status;
        address creator;
    }

    struct UnstakeRequest {
        uint256 stake;
        uint40 unlockAt;
    }

    struct Boost {
        uint40 minerTimestamp;
        uint40 validatorTimestamp;
        uint48 reserved1; // accumulated active time
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

    event NewInference(
        uint256 indexed inferenceId,
        address indexed model,
        address indexed creator,
        uint256 value
    );
    // event InferenceDisputation(address indexed validator, uint256 indexed assigmentId);
    event InferenceStatusUpdate(
        uint256 indexed inferenceId,
        InferenceStatus newStatus
    );

    event NewAssignment(
        uint256 indexed assignmentId,
        uint256 indexed inferenceId,
        address indexed miner,
        uint40 expiredAt
    );
    event MinerRoleSeized(
        uint256 indexed assignmentId,
        uint256 indexed inferenceId,
        address indexed miner
    );
    event SolutionSubmission(
        address indexed miner,
        uint256 indexed assigmentId
    );
    event CommitmentSubmission(
        address indexed miner,
        uint256 indexed assigmentId,
        bytes32 commitment
    );
    event TransferFee(address indexed treasury, uint256 protocolFee);

    event TopUpInfer(
        uint256 indexed inferenceId,
        address indexed creator,
        uint256 value
    );

    event MinerUnstake(address indexed miner, uint256 stake);
    event MinerJoin(address indexed miner);
    event RevealSubmission(
        address indexed miner,
        uint256 indexed assigmentId,
        uint40 nonce,
        bytes output
    );

    event RewardClaim(address indexed worker, uint256 value);

    event RewardPerEpoch(uint256 oldReward, uint256 newReward);
    event BlocksPerEpoch(uint256 oldBlocks, uint256 newBlocks);
    event UnstakeDelayTime(uint256 oldDelayTime, uint256 newDelayTime);
    event SubmitDuration(uint256 oldTime, uint256 newTime);
    event CommitDuration(uint256 oldTime, uint256 newTime);
    event RevealDuration(uint256 oldTime, uint256 newTime);
    event Restake(
        address indexed miner,
        uint256 restake,
        address indexed model
    );

    event MinerDeactivated(
        address indexed miner,
        address indexed modelAddress,
        uint40 activeTime
    );
    event FraudulentMinerPenalized(
        address indexed miner,
        address indexed modelAddress,
        address indexed treasury,
        uint256 fine
    );
    event PenaltyDurationUpdated(uint40 oldDuration, uint40 newDuration);
    event FinePercentageUpdated(uint16 oldPercent, uint16 newPercent);

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
    error InvalidMiner();
    error InvalidData();
    error InvalidRole();

    error MinerInDeactivationTime();
    error InvalidCommitment();
    error AlreadyCommitted();
    error NotCommitted();
    error CommitTimeout();
    error RevealTimeout();
    error InvalidReveal();
    error InvalidNonce();
    error AlreadyRevealed();
}

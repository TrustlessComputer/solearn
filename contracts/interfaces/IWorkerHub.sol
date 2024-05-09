// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IInferable} from "./IInferable.sol";

interface IWorkerHub is IInferable {
    enum InferStatus {
        None,
        Solving,
        Disputed,
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
        uint16 tier;
        uint40 activeTime;
        uint96 lastClaimedEpoch;
    }

    struct Assignment {
        uint256 inferenceId;
        uint256 validationSubmissions;
        address worker;
        uint8 disapproval; // 1 / 3 total val
        bytes output;
    }

    struct Inference {
        uint256[] assignments; // assignment ids solution submitter
        address modelAddress;
        uint256 value;
        bytes input;
        address disputeAddress; // the first validator submit dispute request => punishment
        uint40 expiredAt;
        uint8 firstSubmitterIndex;
        InferStatus status;
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

    event NewAssignment(
        uint256 indexed assignmentId,
        uint256 indexed inferenceId,
        address indexed worker
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

    event RewardPerEpoch(
        uint256 _oldReward,
        uint256 _newReward
    );

    event RewardPerEpochBasedOnPerf(
        uint256 _oldReward,
        uint256 _newReward
    );

    event BlocksPerEpoch(
        uint256 _oldBlocks,
        uint256 _newBlocks
    );

    event MinterUnstake(address minter, uint256 stake);
    event ValidatorUnstake(address validator, uint256 stake);

    error AlreadyRegistered();
    error NotRegistered();
    error Unauthorized();
    error StillBeingLocked();

    error InvalidModel();
    error InvalidTier();

    error FeeTooLow();
    error StakeTooLow();
    error NullStake();

    error MintingSessionNotEnded();
    error ValidatingSessionNotEnded();

}

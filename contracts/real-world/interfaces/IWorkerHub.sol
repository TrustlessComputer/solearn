// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IPromptable} from "./IPromptable.sol";

interface IWorkerHub is IPromptable {
    enum PromptStatus {
        Nil,
        Solving,
        Commit,
        Reveal,
        Processed,
        Killed,
        Transferred
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

    struct PromptData {
        uint256 value; // this value is calculated by msg.value - feeL2 - feeTreasury
        uint256 feeL2;
        uint256 feeTreasury;
        address modelAddress;
        uint40 submitTimeout; // limit time to capture the miner role and submit the solution
        PromptStatus status;
        address creator;
        address processedMiner;
        address referrer;
        bytes input;
        bytes output;
    }

    struct VotingInfo {
        uint8 totalCommit;
        uint8 totalReveal;
    }

    struct DAOTokenPercentage {
        uint16 minerPercentage;
        uint16 userPercentage;
        uint16 referrerPercentage;
        uint16 refereePercentage;
        uint16 l2OwnerPercentage;
    }

    event NewPrompt(
        uint256 indexed promptId,
        address indexed model,
        address indexed creator,
        uint256 value,
        uint256 originPromptId
    );

    event RawSubmitted(
        uint256 indexed promptId,
        address indexed model,
        address indexed creator,
        uint256 value,
        uint256 originPromptId,
        bytes input,
        bool flag
    );

    event PromptStatusUpdate(
        uint256 indexed promptId,
        PromptStatus newStatus
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
    event SolutionSubmission(address indexed miner, uint256 indexed inferId);
    event CommitmentSubmission(
        address indexed miner,
        uint256 indexed assigmentId,
        bytes32 commitment
    );

    event RevealSubmission(
        address indexed miner,
        uint256 indexed assigmentId,
        uint40 nonce,
        bytes output
    );

    event DAOTokenPercentageUpdated(
        DAOTokenPercentage oldValue,
        DAOTokenPercentage newValue
    );
    enum DAOTokenReceiverRole {
        Miner,
        Validator,
        User,
        Referrer,
        Referee,
        L2Owner
    }
    struct DAOTokenReceiverInfor {
        address receiver;
        uint256 amount;
        DAOTokenReceiverRole role;
    }
    event DAOTokenMintedV2(
        uint256 chainId,
        uint256 inferenceId,
        address modelAddress,
        DAOTokenReceiverInfor[] receivers
    );
    event StreamedData(uint256 indexed assignmentId, bytes data);

    error AlreadySubmitted();
    error SubmitTimeout();
    error NotEnoughMiners();
    error Unauthorized();
    error OnlyAssignedWorker();
    error AlreadySeized();
    error InvalidContext();

    error InvalidPromptStatus();
    error CannotFastForward();

    error InvalidMiner();
    error InvalidData();
    error InvalidRole();

    error InvalidCommitment();
    error AlreadyCommitted();
    error NotCommitted();
    error CommitTimeout();
    error RevealTimeout();
    error InvalidReveal();
    error InvalidNonce();
    error AlreadyRevealed();
    error InvalidAddress();

    function getMinFeeToUse(
        address _modelAddress
    ) external view returns (uint256);

    function getTreasuryAddress() external view returns (address);

    function getPromptInfo(
        uint256 _promptId
    ) external view returns (PromptData memory);
}

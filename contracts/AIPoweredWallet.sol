// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface AIKernel {
    function infer(
        bytes calldata _data,
        bool _flag
    ) external payable returns (uint256 referenceId);
}

interface PromptScheduler {
    enum InferenceStatus {
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

    struct Assignment {
        uint256 inferenceId;
        bytes32 commitment;
        bytes32 digest;
        uint40 revealNonce;
        address worker;
        AssignmentRole role;
        Vote vote;
        bytes output;
    }

    struct Inference {
        uint256[] assignments;
        bytes input;
        uint256 value;
        uint256 feeL2;
        uint256 feeTreasury;
        address modelAddress;
        uint40 submitTimeout;
        uint40 commitTimeout;
        uint40 revealTimeout;
        InferenceStatus status;
        address creator;
        address processedMiner;
        address referrer;
    }

    function getInferenceInfo(
        uint256 _inferenceId
    ) external view returns (Inference memory);

    function getAssignmentInfo(
        uint256 _assignmentId
    ) external view returns (Assignment memory);
}

contract AIPoweredWallet {
    address public kernel;
    address public promptScheduler;
    uint256 public currentInferenceId;
    string public context;

    event SuspiciousTransaction(uint256 inferenceId, bytes);

    constructor(address _kernelAddress, address _promptSchedulerAddress) {
        require(
            _kernelAddress != address(0) &&
                _promptSchedulerAddress != address(0),
            "AIPoweredWallet: Invalid address"
        );
        kernel = _kernelAddress;
        promptScheduler = _promptSchedulerAddress;
        context = "";
    }

    function suspiciousTransaction() external {
        string memory prompt = string.concat(
            "Based on the following Ethereum transaction history, is there any indication of suspicious activity? Respond with only 'yes' or 'no'. ",
            context
        );

        currentInferenceId = AIKernel(kernel).infer(bytes(prompt), true);

        emit SuspiciousTransaction(currentInferenceId, bytes(prompt));
    }

    function send(address _receivedWallet) external payable {
        require(msg.value > 0, "AIPoweredWallet: No value sent");

        require(
            _receivedWallet != address(0),
            "AIPoweredWallet: Invalid wallet address"
        );

        if (currentInferenceId != 0) {
            bytes memory result = fetchInferenceResult(currentInferenceId);

            require(
                keccak256(result) == keccak256(abi.encodePacked("No")),
                "AIPoweredWallet: Suspicious transaction"
            );
        }

        payable(_receivedWallet).transfer(msg.value);

        context = string.concat(
            context,
            Strings.toHexString(msg.sender),
            " transfer ",
            Strings.toString(msg.value),
            " wei to ",
            Strings.toHexString(_receivedWallet),
            ". "
        );
    }

    function fetchInferenceResult(
        uint256 _inferenceId
    ) public view returns (bytes memory) {
        PromptScheduler.Inference memory inferInfo = PromptScheduler(
            promptScheduler
        ).getInferenceInfo(_inferenceId);

        if (inferInfo.assignments.length == 0) revert("Wait for inference");

        return
            PromptScheduler(promptScheduler)
                .getAssignmentInfo(inferInfo.assignments[0])
                .output;
    }
}

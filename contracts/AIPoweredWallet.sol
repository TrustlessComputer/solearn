// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IHybridModel} from "./interfaces/IHybridModel.sol";
import {IWorkerHub} from "./interfaces/IWorkerHub.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract AIPoweredWallet {
    address public hybridModel;
    address public workerHub;
    uint256 public currentInferenceId;
    string public topic;

    event SuspiciousTransaction(uint256 inferenceId, bytes);

    constructor(address _hybridModelAddress, address _workerHubAddress) {
        require(
            _hybridModelAddress != address(0) &&
                _workerHubAddress != address(0),
            "AIPoweredWallet: Invalid address"
        );
        hybridModel = _hybridModelAddress;
        workerHub = _workerHubAddress;
        topic = "";
    }

    function getPrompt() external view returns (string memory) {
        return string.concat("Is this ", topic, " suspicious?");
    }

    function suspiciousTransaction() external {
        string memory prompt = string.concat(
            "Based on the following Ethereum transaction history, is there any indication of suspicious activity? Respond with only 'yes' or 'no'. ",
            topic
        );

        currentInferenceId = IHybridModel(hybridModel).infer(
            bytes(prompt),
            true
        );

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

        topic = string.concat(
            topic,
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
        IWorkerHub.Inference memory inferInfo = IWorkerHub(workerHub)
            .getInferenceInfo(_inferenceId);

        if (inferInfo.assignments.length == 0) revert("Wait for inference");

        return
            IWorkerHub(workerHub)
                .getAssignmentInfo(inferInfo.assignments[0])
                .output;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILLMAgent} from "./ILLMAgent.sol";
import {IPromptScheduler} from "../interfaces/IPromptScheduler.sol";
import {IHybridModel} from "../interfaces/IHybridModel.sol";

contract LLMAgent is ILLMAgent, Ownable {
    address internal _promptScheduler;
    address internal _modelAddress;
    string internal _systemPrompt;
    mapping(bytes32 => uint256) private _uuids;

    constructor(
        address promptScheduler_,
        address modelAddress_,
        string memory systemPrompt_
    ) Ownable() {
        _validateAddress(promptScheduler_);
        _validateAddress(modelAddress_);

        _promptScheduler = promptScheduler_;
        _modelAddress = modelAddress_;
        _systemPrompt = systemPrompt_;
    }

    function _validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    function updatePromptScheduler(
        address promptScheduler
    ) external virtual onlyOwner {
        _validateAddress(promptScheduler);
        _promptScheduler = promptScheduler;

        emit PromptSchedulerUpdate(promptScheduler);
    }

    function getPromptSchedulerAddress() external view returns (address) {
        return _promptScheduler;
    }

    function updateModelAddress(
        address modelAddress
    ) external virtual onlyOwner {
        _validateAddress(modelAddress);

        _modelAddress = modelAddress;

        emit ModelUpdate(modelAddress);
    }

    function getModelAddress() external view returns (address) {
        return _modelAddress;
    }

    function updateSystemPrompt(
        string memory systemPrompt
    ) external virtual onlyOwner {
        _systemPrompt = systemPrompt;
        emit SystemPromptUpdate(systemPrompt);
    }

    function getSystemPrompt() external view returns (string memory) {
        return _systemPrompt;
    }

    function prompt(
        bytes32 uuid,
        bytes memory request
    ) public payable virtual override returns (uint256 inferId) {
        if (_uuids[uuid] != 0) revert DuplicateUuid();

        inferId = _forwardToModelContract(request);

        // record the request with uuid
        _uuids[uuid] = inferId;

        emit PromptPerformed(uuid, inferId, msg.sender, request);
    }

    function prompt(
        bytes memory request
    ) public payable virtual override returns (uint256 inferId) {
        inferId = _forwardToModelContract(request);

        emit PromptPerformed(bytes32(0), inferId, msg.sender, request);
    }

    function _forwardToModelContract(
        bytes memory request
    ) internal returns (uint256 inferId) {
        inferId = IHybridModel(_modelAddress).infer(
            abi.encodePacked(bytes(_systemPrompt), ";", request)
        );
    }

    function getResultById(bytes32 uuid) external view returns (bytes memory) {
        uint256 inferId = _uuids[uuid];
        return getResultById(inferId);
    }

    function getResultById(uint256 inferId) public view returns (bytes memory) {
        return
            IPromptScheduler(_promptScheduler).getInferenceInfo(inferId).output;
    }

    function _processBeforeExecution(
        bytes memory externalData
    ) internal virtual {}
}

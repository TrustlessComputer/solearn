// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHybridModel} from "./interfaces/IHybridModel.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IInferable} from "./interfaces/IInferable.sol";

import {HybridModelStorage} from "./storages/HybridModelStorage.sol";

contract HybridModel is
HybridModelStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    string constant private VERSION = "v0.0.1";

    receive() external payable {}

    function initialize(
        address _workerHub,
        uint256 _identifier,
        string calldata _name,
        string calldata _metadata
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        workerHub = _workerHub;
        identifier = _identifier;
        name = _name;
        metadata = _metadata;
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function updateWorkerHub(address _workerHub) external onlyOwner {
        workerHub = _workerHub;
        emit WorkerHubUpdate(_workerHub);
    }

    function updateIdentifier(uint256 _identifier) external onlyOwner {
        identifier = _identifier;
        emit IdentifierUpdate(_identifier);
    }

    function updateName(string calldata _name) external onlyOwner {
        name = _name;
        emit NameUpdate(_name);
    }

    function updateMetadata(string calldata _metadata) external onlyOwner {
        metadata = _metadata;
        emit MetadataUpdate(_metadata);
    }

    function setModelId(uint256 _modelId) external {
        if (identifier != 0) revert ModelIdAlreadySet();
        identifier = _modelId;
        emit IdentifierUpdate(_modelId);
    }

    function infer(bytes calldata _input) external payable whenNotPaused nonReentrant returns (uint256) {
        return IInferable(workerHub).infer{value: msg.value}(_input, msg.sender);
    }
}

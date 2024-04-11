// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHybridModel} from "./interfaces/IHybridModel.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IWorkerHub} from "./interfaces/IWorkerHub.sol";

abstract contract HybridModelStorage is IHybridModel {
    uint256 public identifier;
    uint256 public inferenceCost;

    string public name;
    string public url;

    address public workerHub;

    uint256[50] private __gap;
}

contract HybridModel is
HybridModelStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    function initialize(
        address _workerHub,
        uint256 _identifier,
        string calldata _name,
        string calldata _url,
        uint256 _inferenceCost
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        workerHub = _workerHub;
        identifier = _identifier;
        name = _name;
        url = _url;
        inferenceCost = _inferenceCost;
    }

    function version() external pure returns (string memory) {
        return "v0.0.1";
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

    function updateUrl(string calldata _url) external onlyOwner {
        url = _url;
        emit UrlUpdate(_url);
    }

    function updateInferenceCost(uint256 _inferenceCost) external onlyOwner {
        inferenceCost = _inferenceCost;

        emit InferenceCostUpdate(_inferenceCost);
    }

    function setModelId(uint256 _modelId) external {
        if (identifier != 0) revert ModelIdAlreadySet();
        identifier = _modelId;
        emit IdentifierUpdate(_modelId);
    }

    function infer(bytes calldata _data) external payable whenNotPaused nonReentrant returns (uint256) {
        if (msg.value < inferenceCost) revert InsufficientFunds();

        return IWorkerHub(workerHub).infer{value: msg.value}(_data, identifier, msg.sender);
    }
}

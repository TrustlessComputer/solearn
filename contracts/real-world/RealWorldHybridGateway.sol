// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHybridGateway} from "./interfaces/IHybridGateway.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IInferable} from "../interfaces/IInferable.sol";
import {HybridGatewayStorage} from "./storages/HybridGatewayStorage.sol";

contract RealWorldHybridGateway is
    HybridGatewayStorage,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    string private constant VERSION = "v0.0.1";

    receive() external payable {}

    function initialize(
        address _workerHub,
        address _gatewayCollection,
        uint256 _identifier,
        string calldata _name,
        string calldata _metadata
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        workerHub = _workerHub;
        gatewayCollection = _gatewayCollection;
        identifier = _identifier;
        name = _name;
        metadata = _metadata;
    }

    modifier onlyGatewayCollection() {
        require(
            msg.sender == gatewayCollection,
            "Caller is not the gatewayCollection"
        );
        _;
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

    function setGatewayId(uint256 _gatewayId) external onlyGatewayCollection {
        if (identifier != 0) revert GatewayIdAlreadySet();
        identifier = _gatewayId;
        emit IdentifierUpdate(_gatewayId);
    }

    function infer(
        bytes calldata _input
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        return
            IInferable(workerHub).infer{value: msg.value}(_input, msg.sender);
    }

    function infer(
        bytes calldata _input,
        bool _flag
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        return
            IInferable(workerHub).infer{value: msg.value}(
                _input,
                msg.sender,
                _flag
            );
    }

    function infer(
        bytes calldata _input,
        address _creator
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        return IInferable(workerHub).infer{value: msg.value}(_input, _creator);
    }

    function infer(
        bytes calldata _input,
        address _creator,
        bool _flag
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        return
            IInferable(workerHub).infer{value: msg.value}(
                _input,
                _creator,
                _flag
            );
    }
}

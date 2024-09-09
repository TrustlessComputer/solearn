// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IOnchainModel } from "./interfaces/IOnchainModel.sol";
import { IOnchainImplementation } from "./interfaces/IOnchainImplementation.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

abstract contract OnchainModelStorage is IOnchainModel {
    uint256 public identifier;
    uint256 public inferenceCost;

    string public name;
    address public implementation;

    address public modelRegistry;

    uint256[50] private __gap;
}

contract OnchainModel is
OnchainModelStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    // modifier onlyOwnerOrOperator() {
    //     if (msg.sender != owner() && modelId > 0 && msg.sender != modelRegistry.ownerOf(modelId)) {
    //         revert NotTokenOwner();
    //     }
    //     _;
    // }

    // modifier onlyMintedModel() {
    //     if (modelId == 0) {
    //         revert IncorrectModelId();
    //     }
    //     _;
    // }

    function initialize(
        address _modelRegistry,
        uint256 _identifier,
        string calldata _name,
        address _implementation,
        uint256 _inferenceCost
    ) external initializer nonReentrant {
        if (!IOnchainImplementation(_implementation).isReady()) revert ModelNotReady();

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        modelRegistry = _modelRegistry;
        identifier = _identifier;
        name = _name;
        implementation = _implementation;
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

    function updateModelRegistry(address _modelRegistry) external onlyOwner {
        modelRegistry = _modelRegistry;
        emit ModelRegUpdate(_modelRegistry);
    }

    function updateIdentifier(uint256 _identifier) external onlyOwner {
        identifier = _identifier;
        emit IdentifierUpdate(_identifier);
    }

    function updateName(string calldata _name) external onlyOwner {
        name = _name;
        emit NameUpdate(_name);
    }

    function updateImplementation(address _implementation) external onlyOwner {
        implementation = _implementation;
        emit ImplementationUpdate(_implementation);
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

    function infer(bytes calldata data) external payable {
        if (msg.value < inferenceCost) revert InsufficientFunds();

        bytes memory result = IOnchainImplementation(implementation).infer(data);
        emit InferResult(result);
    }
}

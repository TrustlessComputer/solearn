// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Set} from "./lib/set/Set.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

import {WorkerHubStorage} from "./storages/WorkerHubStorage.sol";

contract WorkerHub is
WorkerHubStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using Set for Set.Uint256Set;
    using Set for Set.AddressSet;

    string constant private VERSION = "v0.0.1";

    receive() external payable {}

    function initialize(
        uint256 _minterMinimumStake,
        uint8 _minterRequirement,
        uint40 _mintingTimeLimit,
        uint256 _validatorMinimumStake,
        uint8 _validatorRequirement,
        uint40 _validatingTimeLimit,
        uint16 _maximumTier
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        minterMinimumStake = _minterMinimumStake;
        minterRequirement = _minterRequirement;
        mintingTimeLimit = _mintingTimeLimit;

        validatorMinimumStake = _validatorMinimumStake;
        validatorRequirement = _validatorRequirement;
        validatingTimeLimit = _validatingTimeLimit;

        minterPivot = 1;

        maximumTier = _maximumTier;
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

    function registerMinter(uint16 tier) external payable {
        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < minterMinimumStake) revert StakeTooLow();

        Worker storage minter = minters[msg.sender];
        if (minter.tier != 0) revert AlreadyRegistered();

        minter.stake = msg.value;
        minter.tier = tier;

        minterAddresses.insert(msg.sender);

        emit MinterRegistration(msg.sender, tier, msg.value);
    }

    function unregisterMinter() external nonReentrant {
        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        if (minter.currentTaskId != 0) revert MintingSessionNotEnded();

        minter.tier = 0;

        TransferHelper.safeTransferNative(msg.sender, minter.stake);
        minter.stake = 0;

        minterAddresses.erase(msg.sender);

        emit MinterUnregistration(msg.sender);
    }

    function increaseMinterStake() external payable {
        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        minter.stake += msg.value;
        emit MinterExtraStake(msg.sender, msg.value);
    }

    function registerValidator(uint16 tier) external payable {
        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < validatorMinimumStake) revert StakeTooLow();

        Worker storage validator = validators[msg.sender];
        if (validator.tier != 0) revert AlreadyRegistered();

        validator.stake = msg.value;
        validator.tier = tier;

        validatorAddresses.insert(msg.sender);

        emit ValidatorRegistration(msg.sender, tier, msg.value);
    }

    function unregisterValidator() external nonReentrant {
        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();
        if (validator.currentTaskId != 0) revert ValidatingSessionNotEnded();

        validator.tier = 0;

        TransferHelper.safeTransferNative(msg.sender, validator.stake);
        validator.stake = 0;

        validatorAddresses.erase(msg.sender);

        emit ValidatorUnregistration(msg.sender);
    }

    function increaseValidatorStake() external payable {
        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();
        validator.stake += msg.value;
        emit ValidatorExtraStake(msg.sender, msg.value);
    }

    function registerModel(address _model, uint16 _tier, uint256 _minimumFee) external onlyOwner returns (uint256) {
        Model storage model = models[_model];
        if (model.modelId != 0) revert AlreadyRegistered();
        uint256 modelId = ++modelNumber;
        model.modelId = modelId;
        model.minimumFee = _minimumFee;
        model.tier = _tier;
        modelAddresses.insert(_model);
        emit ModelRegistration(_model, modelId, _tier, _minimumFee);
        return modelId;
    }

    function unregisterModel(address _model) external {
        Model storage model = models[_model];
        if (model.modelId == 0) revert NotRegistered();
        model.modelId = 0;
        model.tier = 0;
        modelAddresses.erase(_model);
        emit ModelUnregistration(_model);
    }

    function infer(bytes calldata _input, address _creator) external payable returns (uint256) {
        Model storage model = models[msg.sender];
        if (model.tier == 0) revert Unauthorized();
        if (msg.value < model.minimumFee) revert FeeTooLow();
        uint256 inferenceId = ++inferenceNumber;
        Inference storage inference = inferences[inferenceId];
        inference.input = _input;
        inference.value = msg.value;
        inference.creator = _creator;
        inference.modelId = model.modelId;
        inference.outputs = new bytes[](minterRequirement);

        uint256 minterNumber = minterAddresses.size();
        for (uint256 i = 1; i <= minterRequirement; ++i) {
            minterPivot++;
            if (minterPivot > minterNumber) minterPivot = 1;
            uint256 assignmentId = ++mintingAssignmentNumber;
            address minter = minterAddresses.values[minterPivot-1];
            mintingAssignments[assignmentId] = Assignment(
                inferenceId,
                minter,
                uint40(block.timestamp + mintingTimeLimit),
                uint8(i),
                false
            );
            inference.minters.push(minter);
            assignmentsByMinters[minter].insert(assignmentId);
        }

        emit NewInference(inferenceId, _creator, msg.value);

        return inferenceId;
    }

    function getMinterAddresses() external view returns (address[] memory) {
        return minterAddresses.values;
    }

    function getValidatorAddresses() external view returns (address[] memory) {
        return validatorAddresses.values;
    }

    function getModelAddresses() external view returns (address[] memory) {
        return modelAddresses.values;
    }

    function getMinterAssignment() external view returns (uint256) {
        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        if (assignmentsByMinters[msg.sender].isEmpty()) {
            return 0;
        } else {
            return assignmentsByMinters[msg.sender].values[0];
        }
    }

    function getInferenceOutput(uint256 _inferenceId) external view returns (bytes memory) {
        bytes[] storage outputs = inferences[_inferenceId].outputs;
        for (uint256 i = 0; i < outputs.length; ++i) {
            if (outputs[i].length != 0) return inferences[_inferenceId].outputs[i];
        }
        return "";
    }

    function getInferenceInput(uint256 _inferenceId) external view returns (bytes memory) {
        return inferences[_inferenceId].input;
    }

    function submitOutput(uint256 _assignmentId, bytes calldata _output) external {
        Assignment storage assignment = mintingAssignments[_assignmentId];
        if (msg.sender != assignment.worker) revert Unauthorized();
        inferences[assignment.inferenceId].outputs[assignment.index-1] = _output;
        assignmentsByMinters[msg.sender].erase(_assignmentId);
    }
}

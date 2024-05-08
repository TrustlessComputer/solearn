// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Set} from "./lib/Set.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

import {WorkerHubStorage} from "./storages/WorkerHubStorage.sol";

contract WorkerHub is
WorkerHubStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using Set for Set.AddressSet;

    string constant private VERSION = "v0.0.1";
    uint256 constant private PERCENTAGE_DENOMINATOR = 100_00;

    receive() external payable {}

    function initialize(
        uint256 _minterMinimumStake,
        uint256 _validatorMinimumStake,
        uint40 _mintingTimeLimit,
        uint40 _validatingTimeLimit,
        uint40 _disputingTimeLimit,
        uint8 _minterRequirement,
        uint16 _maximumTier,
        uint16 _disqualificationPercentage,
        uint256 _blocksPerEpoch,
        uint256 _rewardPerEpoch,
        uint40 _penaltyDuration,
        uint40 _unstakeDelayTime
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        minterMinimumStake = _minterMinimumStake;
        validatorMinimumStake = _validatorMinimumStake;
        mintingTimeLimit = _mintingTimeLimit;
        validatingTimeLimit = _validatingTimeLimit;
        disputingTimeLimit = _disputingTimeLimit;
        minterRequirement = _minterRequirement;
        maximumTier = _maximumTier;
        disqualificationPercentage = _disqualificationPercentage;
        blocksPerEpoch = _blocksPerEpoch;
        rewardPerEpoch = _rewardPerEpoch;
        penaltyDuration = _penaltyDuration;
        unstakeDelayTime = _unstakeDelayTime;
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

    function registerModel(address _model, uint16 _tier, uint256 _minimumFee) external onlyOwner returns (uint256) {
        _updateEpoch();

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

    function unregisterModel(address _model) external onlyOwner {
        Model storage model = models[_model];
        if (model.modelId == 0) revert NotRegistered();
        model.modelId = 0;
        model.tier = 0;
        modelAddresses.erase(_model);
        emit ModelUnregistration(_model);
    }

    function registerMinter(uint16 tier) external payable {
        _updateEpoch();

        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < minterMinimumStake) revert StakeTooLow();

        Worker storage minter = minters[msg.sender];
        if (minter.tier != 0) revert AlreadyRegistered();

        minter.stake = msg.value;
        minter.tier = tier;

        emit MinterRegistration(msg.sender, tier, msg.value, block.timestamp);
    }

    function unregisterMinter() external nonReentrant {
        _updateEpoch();

        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        if (minter.currentTaskId != 0) revert MintingSessionNotEnded();

        minter.tier = 0;

        TransferHelper.safeTransferNative(msg.sender, minter.stake);
        minter.stake = 0;

        emit MinterUnregistration(msg.sender);
    }

    function increaseMinterStake() external payable {
        _updateEpoch();

        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        minter.stake += msg.value;
        emit MinterExtraStake(msg.sender, msg.value);
    }

    function registerValidator(uint16 tier) external payable {
        _updateEpoch();

        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < validatorMinimumStake) revert StakeTooLow();

        Worker storage validator = validators[msg.sender];
        if (validator.tier != 0) revert AlreadyRegistered();

        validator.stake = msg.value;
        validator.tier = tier;

        emit ValidatorRegistration(msg.sender, tier, msg.value);
    }

    function unregisterValidator() external nonReentrant {
        _updateEpoch();

        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();
        if (validator.currentTaskId != 0) revert ValidatingSessionNotEnded();

        validator.tier = 0;

        TransferHelper.safeTransferNative(msg.sender, validator.stake);
        validator.stake = 0;

        emit ValidatorUnregistration(msg.sender);
    }

    function increaseValidatorStake() external payable {
        _updateEpoch();

        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();
        validator.stake += msg.value;
        emit ValidatorExtraStake(msg.sender, msg.value);
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

        emit NewInference(inferenceId, _creator, msg.value);

        _processMintingTasks();

        return inferenceId;
    }

    function _processMintingTasks() private {

    }

    // this internal function update new epoch
    function _updateEpoch() private {
        if (block.number - lastBlock >= blocksPerEpoch) {
            currentEpoch++;
            lastBlock = block.number;
            rewardInEpoch[currentEpoch].totalReward = rewardPerEpoch;
        }
    }

    // todo: kouchou remove code
    // from here
    function compareAddress(address _a, address _b, int64 _identifier) external view returns (bool) {
        return true;
    }

    function compareUint256(uint256 _a, uint256 _b, int64 _identifier) external view returns (bool) {
        return true;
    }
    // end remove

    // todo
    // kelvin
    // minter submit result for specific infer
    function submitSolution(uint256 _assigmentId, bytes calldata _data) public virtual {
        _updateEpoch();
    }

    // todo
    // validator notice result from minter incorrect and trigger dispute
    function disputeInfer(uint256 _assignmentId) public virtual {
        _updateEpoch();

    }

    // todo
    // resolve pending inferences
    // update infer status
    // called by anyone
    function resolveInfer(uint256 _inferId) public virtual {
        _updateEpoch();

        // switch case
    }

    // todo
    // validator withdraw unstaked token after 21 days
    function withdrawUnstake() public virtual {
        _updateEpoch();
    }

    // todo
    // minter claim reward
    function claimReward() public virtual {
        _updateEpoch();
    }

    // todo
    function setNewRewardInEpoch(uint256 _newRewardAmount) public virtual onlyOwner {
        _updateEpoch();

    }

    // todo
    function setBlocksPerEpoch(uint256 _blocks) public virtual onlyOwner {
        _updateEpoch();
    }

    // sum reward of an minter since last claimed epoch
    function getRewardToClaim(address _minter) public view virtual returns(uint256 totalReward) {
        uint96 lastClaimed = minters[_minter].lastClaimedEpoch;
        for (lastClaimed += 1; lastClaimed < currentEpoch; lastClaimed++) {
            totalReward += rewardInEpoch[uint256(lastClaimed)].totalReward * minterTaskCompleted[_minter][uint256(lastClaimed)] / uint256(rewardInEpoch[uint256(lastClaimed)].totalTaskCompleted) ;
        }
    }
}

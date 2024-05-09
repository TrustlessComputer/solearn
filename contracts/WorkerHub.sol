// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Queue} from "./lib/Queue.sol";
import {Random} from "./lib/Random.sol";
import {Set} from "./lib/Set.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

import {WorkerHubStorage} from "./storages/WorkerHubStorage.sol";

contract WorkerHub is
WorkerHubStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using Queue for Queue.Uint256Queue;
    using Random for Random.Randomizer;
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
        uint256 _rewardPerEpochBasedOnPerf,
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
        rewardPerEpochBasedOnPerf = _rewardPerEpochBasedOnPerf;
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

    function registerModel(address _model, uint16 _tier, uint256 _minimumFee) external onlyOwner {
        _updateEpoch();

        Model storage model = models[_model];
        if (model.tier != 0) revert AlreadyRegistered();
        model.minimumFee = _minimumFee;
        model.tier = _tier;
        modelAddresses.insert(_model);
        emit ModelRegistration(_model, _tier, _minimumFee);
    }

    function unregisterModel(address _model) external onlyOwner {
        Model storage model = models[_model];
        if (model.tier == 0) revert NotRegistered();
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
        minter.lastClaimedEpoch = currentEpoch;
        minterNumber++;

        address modelAddress = modelAddresses.values[randomizer.randomUint256() % modelAddresses.size()];
        minter.modelAddress = modelAddress;
        minterAddressesByModel[modelAddress].insert(msg.sender);

        minterAddresses.insert(msg.sender);
        assignmentsByMinter[msg.sender].init();

        emit MinterRegistration(msg.sender, tier, msg.value);
    }

    function unregisterMinter() external nonReentrant {
        _updateEpoch();

        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();

        minter.tier = 0;
        minterNumber--;

        TransferHelper.safeTransferNative(msg.sender, minter.stake);
        minter.stake = 0;
        minter.commitment = 0;

        minterAddresses.erase(msg.sender);
        minterAddressesByModel[minter.modelAddress].erase(msg.sender);
        minter.modelAddress = address(0);

        minterUnstakeRequests[msg.sender] = UnstakeRequest(
            minter.stake,
            uint40(block.timestamp + unstakeDelayTime)
        );

        // claim reward
        _claimReward(msg.sender);

        emit MinterUnregistration(msg.sender);
    }

    function increaseMinterStake() external payable {
        _updateEpoch();

        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();

        minter.stake += msg.value;

        emit MinterExtraStake(msg.sender, msg.value);
    }

    function unstakeForMinter() external {
        _updateEpoch();

        UnstakeRequest storage unstakeRequest = minterUnstakeRequests[msg.sender];
        if (block.timestamp < unstakeRequest.unlockAt) revert StillBeingLocked();

        uint256 stake = unstakeRequest.stake;
        if (stake == 0) revert NullStake();
        TransferHelper.safeTransferNative(msg.sender, stake);

        emit MinterUnstake(msg.sender, stake);
    }

    function registerValidator(uint16 tier) external payable {
        _updateEpoch();

        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < validatorMinimumStake) revert StakeTooLow();

        Worker storage validator = validators[msg.sender];
        if (validator.tier != 0) revert AlreadyRegistered();

        validator.stake = msg.value;
        validator.tier = tier;
        validator.lastClaimedEpoch = currentEpoch;

        address modelAddress = modelAddresses.values[randomizer.randomUint256() % modelAddresses.size()];
        validator.modelAddress = modelAddress;
        validatorAddressesByModel[modelAddress].insert(msg.sender);

        validatorAddresses.insert(msg.sender);

        emit ValidatorRegistration(msg.sender, tier, msg.value);
    }

    function unregisterValidator() external nonReentrant {
        _updateEpoch();

        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();

        validator.tier = 0;

        TransferHelper.safeTransferNative(msg.sender, validator.stake);
        validator.stake = 0;
        validator.commitment = 0;

        validatorAddresses.erase(msg.sender);
        validatorAddressesByModel[validator.modelAddress].erase(msg.sender);
        validator.modelAddress = address(0);

        validatorUnstakeRequests[msg.sender] = UnstakeRequest(
            validator.stake,
            uint40(block.timestamp + unstakeDelayTime)
        );

        // claim reward
        _claimReward(msg.sender);

        emit ValidatorUnregistration(msg.sender);
    }

    function increaseValidatorStake() external payable {
        _updateEpoch();

        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();

        validator.stake += msg.value;

        emit ValidatorExtraStake(msg.sender, msg.value);
    }

    function unstakeForValidator() external {
        _updateEpoch();

        UnstakeRequest storage unstakeRequest = validatorUnstakeRequests[msg.sender];
        if (block.timestamp < unstakeRequest.unlockAt) revert StillBeingLocked();

        uint256 stake = unstakeRequest.stake;
        if (stake == 0) revert NullStake();
        TransferHelper.safeTransferNative(msg.sender, stake);

        emit ValidatorUnstake(msg.sender, stake);
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
        inference.modelAddress = msg.sender;


        Set.AddressSet storage minters = minterAddressesByModel[msg.sender];
        uint256 n = minterRequirement;
        address[] memory selectedMinters = new address[](n);
        emit NewInference(inferenceId, _creator, msg.value);

        for (uint256 i = 0; i < n; ++i) {
            address minter = minters.values[randomizer.randomUint256() % minters.size()];
            minters.erase(minter);
            uint256 assignmentId = ++assignmentNumber;
            assignments[assignmentId].inferenceId = inferenceId;
            assignments[assignmentId].worker = minter;
            selectedMinters[i] = minter;
            assignmentsByMinter[msg.sender].push(assignmentId);
            emit NewAssignment(assignmentId, inferenceId, minter);
        }

        for (uint256 i = 0; i < n; ++i) minters.insert(selectedMinters[i]);

        return inferenceId;
    }

    function getMintingAssignment() external view returns (uint256) {
        Worker storage minter = minters[msg.sender];
        if (minter.tier == 0) revert NotRegistered();
        if (assignmentsByMinter[msg.sender].isEmpty()) return 0;
        return assignmentsByMinter[msg.sender].front();
    }

    // this internal function update new epoch
    function _updateEpoch() internal {
        if (blocksPerEpoch > 0) {
            uint epochPassed = (block.number - lastBlock) / blocksPerEpoch;
            if (epochPassed > 0) {
                for (; epochPassed > 0; epochPassed--) {
                    rewardInEpoch[currentEpoch].totalMinter = minterNumber;
                    currentEpoch++;
                    rewardInEpoch[currentEpoch].perfReward = rewardPerEpochBasedOnPerf;
                    rewardInEpoch[currentEpoch].epochReward = rewardPerEpoch;
                }
                lastBlock = block.number;
            }
        } else {
            lastBlock = block.number;
        }
    }

    // todo
    // kelvin
    // minter submit result for specific infer
    function submitSolution(uint256 _assigmentId, bytes calldata _data) public virtual {
        _updateEpoch();
        address _msgSender = msg.sender;

        Assignment memory clonedAssignments = assignments[_assigmentId];

        if (_msgSender != clonedAssignments.worker) revert("Sender is invalid");
        if (clonedAssignments.output.length != 0) revert("Assignment already submitted");

        assignments[_assigmentId].output = _data; //Record the solution

        Inference storage inference = inferences[clonedAssignments.inferenceId];

        // if inference.status is not None, the Tx will fail.
        if (inference.status != InferStatus.Solving) {
            revert("Assignment already submitted");
        }
        if (inference.expiredAt > block.timestamp) {
            _assignMinters(clonedAssignments.inferenceId);
        }

        inference.status = InferStatus.Solved;
        uint256[] memory inferAssignments = inference.assignments;
        uint256 assignmentsLen = inferAssignments.length;

        for (uint8 i = 0; i < assignmentsLen; i++) {
            if (inferAssignments[i] == _assigmentId) {
                inference.firstSubmitterIndex = i;
                break;
            }
        }

        uint curEpoch = currentEpoch;
        minterTaskCompleted[_msgSender][curEpoch] += 1;
        rewardInEpoch[curEpoch].totalTaskCompleted += 1;

        emit SubmitSolution(_msgSender, _assigmentId);
    }

    function _handleDisputeSuccess(uint256 _inferId) internal {
        // TODO
    }


    function disputeInfer(uint256 _assignmentId) public virtual {
        // TODO
    }

    // todo
    // resolve pending inferences
    // update infer status
    // called by anyone
    function resolveInfer(uint256 _inferId) public virtual {
        _updateEpoch();

        // switch case
    }

    function _claimReward(address _minter) internal {
        uint256 rewardAmount = rewardToClaim(_minter);
        minters[_minter].lastClaimedEpoch = currentEpoch;
        if (rewardAmount > 0) {
            TransferHelper.safeTransferNative(_minter, rewardAmount);

            emit ClaimReward(_minter, rewardAmount);
        }
    }

    // minter claim reward
    function claimReward(address _minter) public virtual nonReentrant {
        _claimReward(_minter);
    }

    // @dev admin functions
    function setNewRewardInEpoch(uint256 _newRewardAmount) public virtual onlyOwner {
        _updateEpoch();
        emit RewardPerEpoch(rewardPerEpoch, _newRewardAmount);

        rewardPerEpoch = _newRewardAmount;
    }

    function setNewRewardInEpochBasedOnPerf(uint256 _newRewardAmount) public virtual onlyOwner {
        _updateEpoch();
        emit RewardPerEpochBasedOnPerf(rewardPerEpoch, _newRewardAmount);

        rewardPerEpochBasedOnPerf = _newRewardAmount;
    }

    function setBlocksPerEpoch(uint256 _blocks) public virtual onlyOwner {
        _updateEpoch();
        require(_blocks > 0, "invalid blocks value");

        emit BlocksPerEpoch(blocksPerEpoch, _blocks);

        blocksPerEpoch = _blocks;
    }

    // sum reward of an minter since last claimed epoch
    function rewardToClaim(address _minter) public virtual returns(uint256 totalReward) {
        _updateEpoch();

        uint lastEpoch = currentEpoch;
        if (minters[_minter].stake <= 0 || lastEpoch <= minters[_minter].lastClaimedEpoch) {
            totalReward = 0;
        } else {
            uint256 lastClaimed = uint256(minters[_minter].lastClaimedEpoch);
            uint perfReward;
            uint epochReward;
            uint currentMinter;
            for (; lastClaimed < lastEpoch; lastClaimed++) {
                MinterEpochState memory state = rewardInEpoch[lastClaimed];
                uint256 totalTaskCompleted = state.totalTaskCompleted;
                // reward at epoch
                (perfReward, epochReward, currentMinter) = (state.perfReward, state.epochReward, state.totalMinter);
                if (totalTaskCompleted > 0 && perfReward > 0) {
                    totalReward += perfReward * minterTaskCompleted[_minter][lastClaimed] / totalTaskCompleted;
                }

                if (currentMinter > 0 && epochReward > 0) {
                    totalReward += epochReward / currentMinter;
                }
            }
        }
    }
}

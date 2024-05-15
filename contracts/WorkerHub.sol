// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Random} from "./lib/Random.sol";
import {Set} from "./lib/Set.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

import {WorkerHubStorage} from "./storages/WorkerHubStorage.sol";

contract WorkerHub is
WorkerHubStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using Random for Random.Randomizer;
    using Set for Set.AddressSet;
    using Set for Set.Uint256Set;

    string constant private VERSION = "v0.0.1";
    uint256 constant private PERCENTAGE_DENOMINATOR = 100_00;
    uint256 constant private BLOCK_PER_YEAR = 365 days / 2; // 2s per block

    receive() external payable {}

    function initialize(
        address _treasury,
        uint16 _feePercentage,
        uint256 _minerMinimumStake,
        uint256 _validatorMinimumStake,
        uint40 _miningTimeLimit,
        uint8 _minerRequirement,
        uint256 _blocksPerEpoch,
        uint256 _rewardPerEpochBasedOnPerf,
        uint256 _rewardPerEpoch,
        uint40 _unstakeDelayTime
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        treasury = _treasury;
        feePercentage = _feePercentage;
        minerMinimumStake = _minerMinimumStake;
        validatorMinimumStake = _validatorMinimumStake;
        miningTimeLimit = _miningTimeLimit;
        minerRequirement = _minerRequirement;
        blocksPerEpoch = _blocksPerEpoch;
        rewardPerEpochBasedOnPerf = _rewardPerEpochBasedOnPerf;
        rewardPerEpoch = _rewardPerEpoch;
        unstakeDelayTime = _unstakeDelayTime;
        maximumTier = 1;
        lastBlock = block.number;
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

    function getModelAddresses() external view returns (address[] memory) {
        return modelAddresses.values;
    }

    function getMiningAssignments() external view returns (AssignmentInfo[] memory) {
        uint256[] memory assignmentIds = assignmentsByMiner[msg.sender].values;
        uint256 assignmentNumber = assignmentIds.length;

        uint256 counter = 0;
        for (uint256 i = 0; i < assignmentNumber; ++i)
            if (isAssignmentPending(assignmentIds[i])) counter++;

        AssignmentInfo[] memory result = new AssignmentInfo[](counter);
        counter = 0;

        for (uint256 i = 0; i < assignmentNumber; ++i)
            if (isAssignmentPending(assignmentIds[i])) {
                Assignment storage assignment = assignments[assignmentIds[i]];
                Inference storage inference = inferences[assignment.inferenceId];
                result[counter++] = AssignmentInfo(
                    assignmentIds[i],
                    assignment.inferenceId,
                    inference.value,
                    inference.input,
                    inference.modelAddress,
                    inference.creator,
                    inference.expiredAt
                );
            }

        return result;
    }

    function getMintingAssignmentsOfInference(uint256 _inferenceId) external view returns (AssignmentInfo[] memory) {
        uint256[] memory assignmentIds = assignmentsByInference[_inferenceId].values;
        uint256 assignmentNumber = assignmentIds.length;

        AssignmentInfo[] memory result = new AssignmentInfo[](assignmentNumber);
        for (uint256 i = 0; i < assignmentNumber; ++i) {
            Assignment storage assignment = assignments[assignmentIds[i]];
            Inference storage inference = inferences[assignment.inferenceId];
            result[i] = AssignmentInfo(
                assignmentIds[i],
                assignment.inferenceId,
                inference.value,
                inference.input,
                inference.modelAddress,
                inference.creator,
                inference.expiredAt
            );
        }

        return result;
    }

    function getMinerAddresses() external view returns (address[] memory) {
        return minerAddresses.values;
    }

    function getMinerAddressesOfModel(address _model) external view returns (address[] memory) {
        return minerAddressesByModel[_model].values;
    }

    function getValidatorAddressesOfModel(address _model) external view returns (address[] memory) {
        return validatorAddressesByModel[_model].values;
    }


    function getMiners() external view returns (WorkerInfo[] memory) {
        address[] memory addresses = minerAddresses.values;
        uint256 minerNumber = addresses.length;
        WorkerInfo[] memory result = new WorkerInfo[](minerNumber);
        for (uint256 i = 0; i < minerNumber; ++i) {
            Worker memory miner = miners[addresses[i]];
            result[i] = WorkerInfo(
                addresses[i],
                miner.stake,
                miner.commitment,
                miner.modelAddress,
                miner.lastClaimedEpoch,
                miner.activeTime,
                miner.tier
            );
        }
        return result;
    }

    function getValidatorAddresses() external view returns (address[] memory) {
        return validatorAddresses.values;
    }

    function getValidators() external view returns (WorkerInfo[] memory) {
        address[] memory addresses = validatorAddresses.values;
        uint256 validatorNumber = addresses.length;
        WorkerInfo[] memory result = new WorkerInfo[](validatorNumber);
        for (uint256 i = 0; i < validatorNumber; ++i) {
            Worker memory validator = validators[addresses[i]];
            result[i] = WorkerInfo(
                addresses[i],
                validator.stake,
                validator.commitment,
                validator.modelAddress,
                validator.lastClaimedEpoch,
                validator.activeTime,
                validator.tier
            );
        }
        return result;
    }

    function isAssignmentPending(uint256 _assignmentId) public view returns (bool) {
        return assignments[_assignmentId].output.length == 0
            && block.timestamp < inferences[assignments[_assignmentId].inferenceId].expiredAt;
    }

    function getInferences(uint256[] calldata _inferenceIds) external view returns (InferenceInfo[] memory) {
        uint256 inferenceNumber = _inferenceIds.length;
        InferenceInfo[] memory result = new InferenceInfo[](inferenceNumber);
        for (uint256 i = 0; i < inferenceNumber; ++i) {
            Inference storage inference = inferences[_inferenceIds[i]];
            result[i] = InferenceInfo(
                _inferenceIds[i],
                inference.input,
                inference.status == InferenceStatus.Solved
                    ? assignments[inference.assignments[inference.firstSubmissionId]].output
                    : bytes(""),
                inference.value,
                inference.disputingAddress,
                inference.modelAddress,
                inference.expiredAt,
                inference.status,
                inference.creator
            );
        }
        return result;
    }

    function registerModel(address _model, uint16 _tier, uint256 _minimumFee) external onlyOwner {
        _updateEpoch();

        if (_tier == 0) revert InvalidTier();

        Model storage model = models[_model];
        if (model.tier != 0) revert AlreadyRegistered();

        model.minimumFee = _minimumFee;
        model.tier = _tier;
        modelAddresses.insert(_model);

        emit ModelRegistration(_model, _tier, _minimumFee);
    }

    function unregisterModel(address _model) external onlyOwner {
        _updateEpoch();

        Model storage model = models[_model];
        if (model.tier == 0) revert NotRegistered();

        model.tier = 0;
        modelAddresses.erase(_model);

        emit ModelUnregistration(_model);
    }

    function updateModelTier(address _model, uint32 _tier) external onlyOwner {
        _updateEpoch();

        if (_tier == 0) revert InvalidTier();

        Model storage model = models[_model];
        if (model.tier == 0) revert InvalidModel();

        model.tier = _tier;

        emit ModelTierUpdate(_model, _tier);
    }

    function updateModelMinimumFee(address _model, uint256 _minimumFee) external onlyOwner {
        _updateEpoch();

        Model storage model = models[_model];
        if (model.tier == 0) revert InvalidModel();

        model.minimumFee = _minimumFee;

        emit ModelMinimumFeeUpdate(_model, _minimumFee);
    }

    function registerMiner(uint16 tier) external payable whenNotPaused {
        _updateEpoch();

        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < minerMinimumStake) revert StakeTooLow();

        Worker storage miner = miners[msg.sender];
        if (miner.tier != 0) revert AlreadyRegistered();

        miner.stake = msg.value;
        miner.tier = tier;

        address modelAddress = modelAddresses.values[randomizer.randomUint256() % modelAddresses.size()];
        miner.modelAddress = modelAddress;

        emit MinerRegistration(msg.sender, tier, msg.value);
    }

    function joinForMinting() external whenNotPaused {
        _updateEpoch();

        Worker storage miner = miners[msg.sender];
        if (miner.tier == 0) revert NotRegistered();
        if (miner.stake < minerMinimumStake) revert StakeTooLow();
        if (block.timestamp < miner.activeTime) revert ("Miner in slashing time");

        address modelAddress = miner.modelAddress;
        minerAddressesByModel[modelAddress].insert(msg.sender);
        minerAddresses.insert(msg.sender);
        miner.lastClaimedEpoch = currentEpoch;

        emit MinerJoin(msg.sender);
    }

    function unregisterMiner() external nonReentrant {
        _updateEpoch();

        Worker storage miner = miners[msg.sender];
        if (miner.tier == 0) revert NotRegistered();

        miner.tier = 0;

        uint stakeAmount = miner.stake;
        miner.stake = 0;
        miner.commitment = 0;

        if (minerAddresses.hasValue(msg.sender)) {
            _claimReward(msg.sender);
            minerAddresses.erase(msg.sender);
            minerAddressesByModel[miner.modelAddress].erase(msg.sender);
        }
        miner.modelAddress = address(0);

        uint currentUnstake = minerUnstakeRequests[msg.sender].stake;
        minerUnstakeRequests[msg.sender] = UnstakeRequest(
            stakeAmount + currentUnstake,
            uint40(block.timestamp + unstakeDelayTime)
        );

        emit MinerUnregistration(msg.sender);
    }

    function increaseMinerStake() external payable whenNotPaused {
        _updateEpoch();

        Worker storage miner = miners[msg.sender];
        if (miner.tier == 0) revert NotRegistered();

        miner.stake += msg.value;

        emit MinerExtraStake(msg.sender, msg.value);
    }

    function unstakeForMiner() external {
        _updateEpoch();

        UnstakeRequest storage unstakeRequest = minerUnstakeRequests[msg.sender];
        if (block.timestamp < unstakeRequest.unlockAt) revert StillBeingLocked();

        uint256 stake = unstakeRequest.stake;
        if (stake == 0) revert NullStake();
        unstakeRequest.stake = 0;
        TransferHelper.safeTransferNative(msg.sender, stake);

        emit MinerUnstake(msg.sender, stake);
    }

    function restakeForMiner(uint16 tier) external {
        _updateEpoch();

        UnstakeRequest storage unstakeRequest = minerUnstakeRequests[msg.sender];
        if (unstakeRequest.stake == 0) revert ZeroValue();
        uint unstakeAmount = unstakeRequest.stake;
        unstakeRequest.stake = 0;

        Worker storage miner = miners[msg.sender];
        miner.stake += unstakeAmount;
        if (miner.tier == 0) {
            if (tier == 0 || tier > maximumTier) revert InvalidTier();
            miner.tier = tier;
        }

        if (miner.modelAddress == address(0)) {
            address modelAddress = modelAddresses.values[randomizer.randomUint256() % modelAddresses.size()];
            miner.modelAddress = modelAddress;
        }

        emit Restake(msg.sender, unstakeAmount, miner.modelAddress);
    }

    function registerValidator(uint16 tier) external payable whenNotPaused {
        _updateEpoch();

        if (tier == 0 || tier > maximumTier) revert InvalidTier();
        if (msg.value < validatorMinimumStake) revert StakeTooLow();

        Worker storage validator = validators[msg.sender];
        if (validator.tier != 0) revert AlreadyRegistered();

        validator.stake = msg.value;
        validator.tier = tier;
        validator.tier = tier;
        validator.lastClaimedEpoch = currentEpoch;

        address modelAddress = modelAddresses.values[randomizer.randomUint256() % modelAddresses.size()];
        validator.modelAddress = modelAddress;

        emit ValidatorRegistration(msg.sender, tier, msg.value);
    }

    function joinForValidating() external whenNotPaused {
        _updateEpoch();


        Worker storage validator = miners[msg.sender];
        if (validator.tier == 0) revert NotRegistered();
        if (block.timestamp < validator.activeTime) revert ("Validator in slashing time");

        address modelAddress = validator.modelAddress;
        validatorAddressesByModel[modelAddress].insert(msg.sender);

        validatorAddresses.insert(msg.sender);

        emit ValidatorJoin(msg.sender);
    }

    function unregisterValidator() external nonReentrant {
        _updateEpoch();

        Worker storage validator = validators[msg.sender];
        if (validator.tier == 0) revert NotRegistered();

        validator.tier = 0;

        uint stakeAmount = validator.stake;
        validator.stake = 0;
        validator.commitment = 0;

        validatorAddresses.erase(msg.sender);
        validatorAddressesByModel[validator.modelAddress].erase(msg.sender);
        validator.modelAddress = address(0);

        uint currentUnstake = validatorUnstakeRequests[msg.sender].stake;
        validatorUnstakeRequests[msg.sender] = UnstakeRequest(
            stakeAmount + currentUnstake,
            uint40(block.timestamp + unstakeDelayTime)
        );

        emit ValidatorUnregistration(msg.sender);
    }

    function increaseValidatorStake() external payable whenNotPaused {
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
        unstakeRequest.stake = 0;
        TransferHelper.safeTransferNative(msg.sender, stake);

        emit ValidatorUnstake(msg.sender, stake);
    }

    function infer(bytes calldata _input, address _creator) external payable whenNotPaused returns (uint256) {
        Model storage model = models[msg.sender];
        if (model.tier == 0) revert Unauthorized();
        if (msg.value < model.minimumFee) revert FeeTooLow();
        uint256 inferenceId = ++inferenceNumber;
        Inference storage inference = inferences[inferenceId];

        uint256 value = msg.value;

        inference.input = _input;
        inference.value = value;
        inference.creator = _creator;
        inference.modelAddress = msg.sender;

        emit NewInference(inferenceId, msg.sender, _creator, value);

        _assignMiners(inferenceId);

        return inferenceId;
    }

    function topUpInfer(uint256 _inferenceId) external payable whenNotPaused {
        if (msg.value == 0) revert ZeroValue();

        Inference storage inference = inferences[_inferenceId];
        if (inference.status != InferenceStatus.Solving) revert InferMustBeSolvingState();
        inference.value += msg.value;

        emit TopUpInfer(_inferenceId, inference.creator, inference.value);
    }

    function _assignMiners(uint256 _inferenceId) private {
        uint40 expiredAt = uint40(block.timestamp + miningTimeLimit);
        inferences[_inferenceId].expiredAt = expiredAt;
        inferences[_inferenceId].status = InferenceStatus.Solving;

        address model = inferences[_inferenceId].modelAddress;
        if (minerAddressesByModel[model].size() < minerRequirement) revert NotEnoughMiners();

        Set.AddressSet storage miners = minerAddressesByModel[model];
        uint256 n = minerRequirement;
        address[] memory selectedMiners = new address[](n);

        for (uint256 i = 0; i < n; ++i) {
            address miner = miners.values[randomizer.randomUint256() % miners.size()];
            miners.erase(miner);
            uint256 assignmentId = ++assignmentNumber;
            assignments[assignmentId].inferenceId = _inferenceId;
            assignments[assignmentId].worker = miner;
            selectedMiners[i] = miner;
            assignmentsByMiner[miner].insert(assignmentId);
            assignmentsByInference[_inferenceId].insert(assignmentId);
            emit NewAssignment(assignmentId, _inferenceId, miner, expiredAt);
        }

        for (uint256 i = 0; i < n; ++i) miners.insert(selectedMiners[i]);
    }

    // this internal function update new epoch
    function _updateEpoch() internal {
        if (blocksPerEpoch > 0) {
            uint256 epochPassed = (block.number - lastBlock) / blocksPerEpoch;
            if (epochPassed > 0) {
                // reward for this epoch
                // rewardPerEpoch (reward one year for 1 miner)
                // rewardPerEpoch * total miner * blocker per epoch / blocks per year
                uint256 rewardInCurrentEpoch = rewardPerEpoch * minerAddresses.size() * blocksPerEpoch / BLOCK_PER_YEAR;
                uint256 perfReward = rewardInCurrentEpoch * rewardPerEpochBasedOnPerf / PERCENTAGE_DENOMINATOR;
                uint256 equalReward = rewardInCurrentEpoch - perfReward;

                for (; epochPassed > 0; epochPassed--) {
                    rewardInEpoch[currentEpoch].totalMiner = minerAddresses.size();
                    rewardInEpoch[currentEpoch].perfReward = perfReward;
                    rewardInEpoch[currentEpoch].epochReward = equalReward;
                    currentEpoch++;
                }
                lastBlock = block.number;
            }
        } else {
            lastBlock = block.number;
        }
    }


    function submitSolution(uint256 _assignmentId, bytes calldata _data) public virtual whenNotPaused {
        _updateEpoch();
        address _msgSender = msg.sender;

        Assignment memory clonedAssignments = assignments[_assignmentId];

        // check msgSender is miner
        if (_msgSender != clonedAssignments.worker) revert Unauthorized();
        if (clonedAssignments.output.length != 0) revert AlreadySubmitted();

        Inference memory clonedInference = inferences[clonedAssignments.inferenceId];

        if (clonedInference.status != InferenceStatus.Solving &&
            clonedInference.status != InferenceStatus.Solved)
        {
            revert InvalidInferenceStatus();
        }

        if (clonedInference.expiredAt < block.timestamp) {
            if (clonedInference.assignments.length == 0) {
                resolveInference(clonedAssignments.inferenceId);
                return;
            } else {
                revert MiningSessionEnded();
            }
        }

        Inference storage inference = inferences[clonedAssignments.inferenceId];

        assignments[_assignmentId].output = _data; //Record the solution
        inference.status = InferenceStatus.Solved;
        inference.assignments.push(_assignmentId);

        if (inference.assignments.length == 1) {
            uint256 curEpoch = currentEpoch;
            minerTaskCompleted[_msgSender][curEpoch] += 1;
            rewardInEpoch[curEpoch].totalTaskCompleted += 1;

            uint256 fee = clonedInference.value * feePercentage / PERCENTAGE_DENOMINATOR;
            uint256 value = clonedInference.value * minerFeePercentage / PERCENTAGE_DENOMINATOR;
            TransferHelper.safeTransferNative(treasury, fee);
            TransferHelper.safeTransferNative(_msgSender, value);

            emit TransferFee(_msgSender, value, treasury, fee);
            emit InferenceStatusUpdate(clonedAssignments.inferenceId, InferenceStatus.Solved);
        }

        emit SolutionSubmission(_msgSender, _assignmentId);
    }

    function _handleDisputeSuccess(uint256 _inferId) internal {
        // TODO
    }


    //Check whether a worker is available (the worker had previously joined).
    function _checkAvailableWorker() internal view {
        if (!validatorAddresses.hasValue(msg.sender)) {
            if (!minerAddresses.hasValue(msg.sender)) revert  InvalidMiner();

            address modelAddrOfMiner = miners[msg.sender].modelAddress;
            if (!minerAddressesByModel[modelAddrOfMiner].hasValue(msg.sender)) revert InvalidMiner();
        }

        address modelAddrOfValidator = validators[msg.sender].modelAddress;
        if (!validatorAddressesByModel[modelAddrOfValidator].hasValue(msg.sender)) revert InvalidValidator();
    }

    function _beforeDispute(uint256 _inferId) internal view returns(uint40, uint40){
        Inference memory clonedInference = inferences[_inferId];
        uint256[] memory assignmentIds = clonedInference.assignments;

        // Check case: There is only one submission. TODO: handle (kelvin)
        if (assignmentIds.length == 1) revert LoneSubmissionNoDispute();
        if (assignmentIds.length == 0) revert SubmissionsEmpty();
        if (clonedInference.status != InferenceStatus.Solved) revert InvalidInferenceStatus();

        // Verify if this inference has been disputed
        if(disputedInferIds.hasValue(_inferId)) revert InferenceAlreadyDisputed();

        uint40 validateExpireTimestamp = uint40(clonedInference.expiredAt + validatingTimeLimit);
        uint40 disputeExpiredTimestamp = uint40(clonedInference.expiredAt + validatingTimeLimit + disputingTimeLimit);

        // Verify whether the dispute is raised within the permitted time window
        if (block.timestamp < clonedInference.expiredAt) revert PrematureValidate();
        if (validateExpireTimestamp < block.timestamp) revert ValidateTimeout();

        return (validateExpireTimestamp, disputeExpiredTimestamp);
    }

    function noDispute(uint256 _inferId) public {
        _updateEpoch();
        _checkAvailableWorker();
        // TODO: following new logic, we must check the msg.sender has been assigned the task.

        (uint40 validateExpireTimestamp, uint40 disputeExpiredTimestamp) = _beforeDispute(_inferId);

        Inference memory clonedInference = inferences[_inferId];
        uint256 value = clonedInference.value * (PERCENTAGE_DENOMINATOR - feePercentage - minerFeePercentage) / PERCENTAGE_DENOMINATOR;

        TransferHelper.safeTransferNative(msg.sender, value);

        emit NoDisputeInference(msg.sender, _inferId, uint40(block.timestamp), value);
    }

    function disputeInfer(uint256 _inferId) public virtual {
        _updateEpoch();
        _checkAvailableWorker();

        (uint40 validateExpireTimestamp, uint40 disputeExpiredTimestamp) = _beforeDispute(_inferId);

        disputedInferIds.insert(_inferId);
        // disputedInfersOf[msg.sender].insert(_inferId);

        DisputedInfer storage disputedInfer = disputedInfers[_inferId];
        disputedInfer.totalValidator = uint16(validatorAddresses.values.length);
        disputedInfer.validatingExpireAt = validateExpireTimestamp;
        disputedInfer.disputingExpireAt = disputeExpiredTimestamp;

        //inference
        Inference storage inference = inferences[_inferId];
        inference.disputingAddress = msg.sender;
        inference.status = InferenceStatus.Disputing;

        emit InferenceStatusUpdate(_inferId, InferenceStatus.Disputing);
        emit DisputeInference(msg.sender, _inferId, uint40(block.timestamp), validateExpireTimestamp, disputeExpiredTimestamp);
    }

    function upvoteDispute(uint256 _inferId, Ballot[] calldata ballots) public virtual {
        _updateEpoch();

        if (ballots.length == 0) revert BallotEmpty();

        // Check whether a validator is available (the validator had previously joined).
        if (!validatorAddresses.hasValue(msg.sender)) revert InvalidValidator();
        address modelAddr = validators[msg.sender].modelAddress;
        if (!validatorAddressesByModel[modelAddr].hasValue(msg.sender)) revert InvalidValidator();

        Inference memory clonedInference = inferences[_inferId];
        DisputedInfer memory disputedInfer = disputedInfers[_inferId];

        if (clonedInference.assignments.length == 0) revert SubmissionsEmpty();
        if (clonedInference.status != InferenceStatus.Disputing) revert InvalidInferenceStatus();

        // Verify if this assignment has been disputed.
        if (!disputedInferIds.hasValue(_inferId)) revert InferenceNotDisputed();

        // Verify if the dispute period has ended
        if (block.timestamp < disputedInfer.disputingExpireAt) revert PrematureDispute();
        if (disputedInfer.disputingExpireAt < block.timestamp) revert DisputeTimeout();

        // Each person is only allowed to vote once.
        if (votersOf[_inferId].hasValue(msg.sender)) revert ValidatorVoteExists();

        uint256 ballotsLen = ballots.length;

        for (uint256 i = 0; i < ballotsLen; i++) {
            if (!ballots[i].result) {
                assignments[ballots[i].assignmentId].disapprovalCount++;
            }
        }

        // disputedInfersOf[msg.sender].insert(_inferId);
        votersOf[_inferId].insert(msg.sender);

        emit DisputeUpvote(msg.sender, _inferId, uint40(block.timestamp));

        //TODO: If the reaction time expires but the number of ballots is less than 2/3, 
        // should we extend the waiting time for validators or slash inactive validators and initiate a new vote?
    }

    function resolveDispute(uint256 _inferId) public {
        _updateEpoch();

        // Verify if this assignment has been disputed.
        if (!disputedInferIds.hasValue(_inferId)) revert InferenceNotDisputed();

        Inference memory inference = inferences[_inferId];
        DisputedInfer memory disputedInfer = disputedInfers[_inferId];

        if (block.timestamp < disputedInfer.disputingExpireAt) revert PrematureDispute();
        if (inference.status != InferenceStatus.Disputing) revert InvalidInferenceStatus();

        // TODO: Handling the 'No voter' edge case
        // votersOf[_inferId].values == 0

        uint16 totalValidator = disputedInfer.totalValidator;

        uint256[] memory assignmentIds = inference.assignments;
        uint256 assignmentsLen = assignmentIds.length;
        address[] memory fraudMiners = new address[](minerRequirement);

        uint256 counter = 0;
        bool isDisputeValid = true;

        for (uint256 i = 0; i < assignmentsLen; i++){
            Assignment memory assignment = assignments[assignmentIds[i]];
            // A dispute will be invalid if the disapproval count for a submission falls outside the range of 1/3 to 2/3 of the total number of validators.
            if (totalValidator <= assignment.disapprovalCount * 3  && assignment.disapprovalCount * 3 <= totalValidator * 2) {
                isDisputeValid = false;
            } else if ( totalValidator * 2 < assignment.disapprovalCount * 3 ) {
                fraudMiners[counter++] = assignment.worker;
            }
        }

        //deactivate and slash 
        _cullInactiveValidator(_inferId);

        if (isDisputeValid) {
            // Slash the fraud miners
            uint256 fraudMinersLen = fraudMiners.length;

            for (uint256 i = 0; i < fraudMinersLen; i++) {
                if (fraudMiners[i] == address(0)) break;
                _slashMiner(fraudMiners[i]);
            }

            emit DisputeResolving(_inferId, inference.modelAddress, isDisputeValid);
        } else {
            _slashValidator(inference.disputingAddress);
        }

        inferences[_inferId].status = InferenceStatus.Solved;
        
        emit InferenceStatusUpdate(_inferId, InferenceStatus.Solved);
    }

    // Pruning when validator lazy to vote
    function _cullInactiveValidator(uint256 _inferId) internal {
        address modelAddr = inferences[_inferId].modelAddress;

        address[] memory validators = validatorAddressesByModel[modelAddr].values;
        uint256 validatorsLen = validators.length;
        if (validatorsLen == 0) return;

        Set.AddressSet storage votersSet = votersOf[_inferId];
        uint256 votersLen = votersSet.values.length;

        if (votersLen == validatorsLen) return;

        address[] memory inactiveValidators = new address[](validatorsLen - votersLen);
        uint16 counter = 0;

        for (uint256 i = 0; i < validatorsLen; i++) {
            if (!votersSet.hasValue(validators[i])) {
                inactiveValidators[counter++] = validators[i];
            }
        }

        uint256 len = inactiveValidators.length;

        for (uint256 i = 0; i < len; i++) {
            _deactivateValidator(inactiveValidators[i]);
        }
    }

    function _deactivateValidator(address _validator) internal {
        Worker storage validator = validators[_validator];

        if (!validatorAddresses.hasValue(_validator)) revert ("Validator does not exist");

        address modelAddress = validator.modelAddress;

        // Double check hasValue
        if (validatorAddressesByModel[modelAddress].hasValue(_validator)) {
            validatorAddressesByModel[modelAddress].erase(_validator);
            validatorAddresses.erase(_validator);
        }

        validator.activeTime = uint40(block.timestamp + slashingValidatorTimeLimit);

        emit ValidatorDeactivated(_validator, modelAddress, validator.activeTime);
    }

    function _slashValidator(address _validator) internal {
        Worker storage validator = validators[_validator];

        if (!validatorAddresses.hasValue(_validator)) revert InvalidValidator();

        address modelAddress = validator.modelAddress;

        if (validatorAddressesByModel[modelAddress].hasValue(_validator)) {
            validatorAddressesByModel[modelAddress].erase(_validator);
            validatorAddresses.erase(_validator);
        }

        validator.activeTime = uint40(block.timestamp + slashingValidatorTimeLimit);
        uint256 fine = validator.stake * 5 / 100;
        validator.stake -= fine;

        TransferHelper.safeTransferNative(treasury, fine);

        emit FraudulentValidatorPenalized(_validator, modelAddress, treasury, fine);
    }

    function _slashMiner(address _miner) internal {
        Worker storage miner = miners[_miner];

        if (!minerAddresses.hasValue(_miner)) revert InvalidMiner();

        address modelAddress = miner.modelAddress;

        // Remove miner from available miner
        if (minerAddressesByModel[modelAddress].hasValue(_miner)) {
            minerAddressesByModel[modelAddress].erase(_miner);
            minerAddresses.erase(_miner);
        }

        // Set the time miner can join again
        miner.activeTime = uint40(block.timestamp + slashingMinerTimeLimit);
        uint256 fine = miner.stake * 5 / 100; // Fine = stake * 5%
        miner.stake -= fine;

        TransferHelper.safeTransferNative(treasury, fine);

        emit FraudulentMinerPenalized(_miner, modelAddress, treasury, fine);
    }

    function resolveInference(uint256 _inferenceId) public virtual {
        _updateEpoch();

        Inference storage inference = inferences[_inferenceId];
        if (inference.status == InferenceStatus.Solving && block.timestamp > inference.expiredAt) {
            inference.status = InferenceStatus.Killed;
            TransferHelper.safeTransferNative(inference.creator, inference.value);
            emit InferenceStatusUpdate(_inferenceId, InferenceStatus.Killed);
        }
    }

    function _claimReward(address _miner) internal whenNotPaused {
        uint256 rewardAmount = rewardToClaim(_miner);
        miners[_miner].lastClaimedEpoch = currentEpoch;
        if (rewardAmount > 0) {
            TransferHelper.safeTransferNative(_miner, rewardAmount);

            emit RewardClaim(_miner, rewardAmount);
        }
    }

    // miner claim reward
    function claimReward(address _miner) public virtual nonReentrant {
        _claimReward(_miner);
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
        if (_blocks == 0) revert InvalidBlockValue();

        emit BlocksPerEpoch(blocksPerEpoch, _blocks);

        blocksPerEpoch = _blocks;
    }

    function setUnstakDelayTime(uint40 _newUnstakeDelayTime) public virtual onlyOwner {
        _updateEpoch();

        require(_newUnstakeDelayTime != 0, "invalid unstake delay time");

        emit UnstakeDelayTime(unstakeDelayTime, _newUnstakeDelayTime);

        unstakeDelayTime = _newUnstakeDelayTime;
    }

    // sum reward of an miner since last claimed epoch
    function rewardToClaim(address _miner) public virtual returns(uint256) {
        _updateEpoch();

        uint256 totalReward;
        uint256 lastEpoch = currentEpoch;
        if (!minerAddresses.hasValue(_miner) || lastEpoch <= miners[_miner].lastClaimedEpoch) {
            totalReward = 0;
        } else {
            uint256 lastClaimed = uint256(miners[_miner].lastClaimedEpoch);
            uint256 perfReward;
            uint256 epochReward;
            uint256 currentMiner;
            for (; lastClaimed < lastEpoch; lastClaimed++) {
                MinerEpochState memory state = rewardInEpoch[lastClaimed];
                uint256 totalTaskCompleted = state.totalTaskCompleted;
                // reward at epoch
                (perfReward, epochReward, currentMiner) = (state.perfReward, state.epochReward, state.totalMiner);
                if (totalTaskCompleted > 0 && perfReward > 0) {
                    totalReward += perfReward * minerTaskCompleted[_miner][lastClaimed] / totalTaskCompleted;
                }

                if (currentMiner > 0 && epochReward > 0) {
                    totalReward += epochReward / currentMiner;
                }
            }
        }

        return totalReward;
    }
}

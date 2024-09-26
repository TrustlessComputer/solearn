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
    ReentrancyGuardUpgradeable
{
    using Random for Random.Randomizer;
    using Set for Set.AddressSet;
    using Set for Set.Uint256Set;
    using Set for Set.Bytes32Set;

    string private constant VERSION = "v0.0.2";
    uint256 private constant PERCENTAGE_DENOMINATOR = 100_00;
    uint256 private constant BLOCK_PER_YEAR = 365 days / 2; // 2s per block

    receive() external payable {}

    function initialize(
        address _treasury,
        uint16 _feePercentage,
        uint256 _minerMinimumStake,
        uint8 _minerRequirement,
        uint8 _votingRequirement,
        uint256 _blocksPerEpoch,
        uint256 _rewardPerEpoch,
        uint40 _unstakeDelayTime,
        uint40 _penaltyDuration,
        uint16 _finePercentage,
        uint16 _feeRatioMinerValidor
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        treasury = _treasury;
        feePercentage = _feePercentage;
        feeRatioMinerValidator = _feeRatioMinerValidor;
        minerMinimumStake = _minerMinimumStake;
        minerRequirement = _minerRequirement;
        votingRequirement = _votingRequirement;
        blocksPerEpoch = _blocksPerEpoch;
        rewardPerEpoch = _rewardPerEpoch;
        unstakeDelayTime = _unstakeDelayTime;
        maximumTier = 1;
        lastBlock = block.number;
        penaltyDuration = _penaltyDuration;
        finePercentage = _finePercentage;
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

    function getMintingAssignmentsOfInference(
        uint256 _inferenceId
    ) external view returns (AssignmentInfo[] memory) {
        uint256[] memory assignmentIds = assignmentsByInference[_inferenceId]
            .values;
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
                uint40(block.timestamp) // TODO: kelvin check again
                // inference.expiredAt
            );
        }

        return result;
    }

    function getNOMiner() external view returns (uint) {
        return minerAddresses.values.length;
    }

    function getMinerAddresses() external view returns (address[] memory) {
        return minerAddresses.values;
    }

    function getMinerAddressesOfModel(
        address _model
    ) external view returns (address[] memory) {
        return minerAddressesByModel[_model].values;
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

    function registerModel(
        address _model,
        uint16 _tier,
        uint256 _minimumFee
    ) external onlyOwner {
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

    function updateModelMinimumFee(
        address _model,
        uint256 _minimumFee
    ) external onlyOwner {
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

        address modelAddress = modelAddresses.values[
            randomizer.randomUint256() % modelAddresses.size()
        ];
        miner.modelAddress = modelAddress;

        emit MinerRegistration(msg.sender, tier, msg.value);
    }

    function forceChangeModelForMiner(
        address _miner,
        address _modelAddress
    ) external onlyOwner {
        _updateEpoch();

        if (models[_modelAddress].tier == 0) revert InvalidModel();
        if (!minerAddresses.hasValue(_miner)) revert NotRegistered();

        address currentModelAddress = miners[_miner].modelAddress;
        require(currentModelAddress != _modelAddress, "Same model address");
        minerAddressesByModel[currentModelAddress].erase(_miner);
        minerAddressesByModel[_modelAddress].insert(_miner);

        miners[_miner].modelAddress = _modelAddress;
        miners[_miner].tier = uint16(models[_modelAddress].tier);
    }

    function joinForMinting() external whenNotPaused {
        _updateEpoch();

        Worker storage miner = miners[msg.sender];
        if (miner.tier == 0) revert NotRegistered();
        if (miner.stake < minerMinimumStake) revert StakeTooLow();
        if (block.timestamp < miner.activeTime)
            revert MinerInDeactivationTime();

        address modelAddress = miner.modelAddress;
        minerAddressesByModel[modelAddress].insert(msg.sender);
        minerAddresses.insert(msg.sender);
        miner.lastClaimedEpoch = currentEpoch;
        boost[msg.sender].minerTimestamp = uint40(block.timestamp);

        emit MinerJoin(msg.sender);
    }

    function unregisterMiner() external nonReentrant whenNotPaused {
        _updateEpoch();

        Worker storage miner = miners[msg.sender];
        if (miner.tier == 0) revert NotRegistered();

        miner.tier = 0;

        uint stakeAmount = miner.stake;
        miner.stake = 0;
        miner.commitment = 0;

        if (minerAddresses.hasValue(msg.sender)) {
            _claimReward(msg.sender, false);
            // reset boost
            boost[msg.sender].reserved1 = 0;
            boost[msg.sender].minerTimestamp = uint40(block.timestamp);

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

        UnstakeRequest storage unstakeRequest = minerUnstakeRequests[
            msg.sender
        ];
        if (block.timestamp < unstakeRequest.unlockAt)
            revert StillBeingLocked();

        uint256 stake = unstakeRequest.stake;
        if (stake == 0) revert NullStake();
        unstakeRequest.stake = 0;
        TransferHelper.safeTransferNative(msg.sender, stake);

        emit MinerUnstake(msg.sender, stake);
    }

    function restakeForMiner(uint16 tier) external whenNotPaused {
        _updateEpoch();

        UnstakeRequest storage unstakeRequest = minerUnstakeRequests[
            msg.sender
        ];
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
            address modelAddress = modelAddresses.values[
                randomizer.randomUint256() % modelAddresses.size()
            ];
            miner.modelAddress = modelAddress;
        }

        emit Restake(msg.sender, unstakeAmount, miner.modelAddress);
    }

    function infer(
        bytes calldata _input,
        address _creator
    ) external payable whenNotPaused returns (uint256) {
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
        if (inference.status != InferenceStatus.Solving)
            revert InferMustBeSolvingState();
        inference.value += msg.value;

        emit TopUpInfer(_inferenceId, inference.creator, inference.value);
    }

    function _assignMiners(uint256 _inferenceId) private {
        uint40 expiredAt = uint40(block.timestamp + submitDuration);
        uint40 commitTimeout = expiredAt + commitDuration;
        inferences[_inferenceId].submitTimeout = expiredAt;
        inferences[_inferenceId].commitTimeout = commitTimeout;
        inferences[_inferenceId].revealTimeout = commitTimeout + revealDuration;
        inferences[_inferenceId].status = InferenceStatus.Solving;

        address model = inferences[_inferenceId].modelAddress;
        if (minerAddressesByModel[model].size() < minerRequirement)
            // TODO: check when imp slashing feature
            revert NotEnoughMiners();

        Set.AddressSet storage miners = minerAddressesByModel[model];
        uint256 n = minerRequirement;
        address[] memory selectedMiners = new address[](n);

        for (uint256 i = 0; i < n; ++i) {
            address miner = miners.values[
                randomizer.randomUint256() % miners.size()
            ];
            miners.erase(miner);
            uint256 assignmentId = ++assignmentNumber;
            assignments[assignmentId].inferenceId = _inferenceId;
            assignments[assignmentId].worker = miner;
            assignments[assignmentId].role = AssignmentRole.Validating;

            selectedMiners[i] = miner;
            assignmentsByMiner[miner].insert(assignmentId);
            assignmentsByInference[_inferenceId].insert(assignmentId);
            emit NewAssignment(assignmentId, _inferenceId, miner, expiredAt);
        }

        for (uint256 i = 0; i < n; ++i) miners.insert(selectedMiners[i]);
    }

    function seizeMinerRole(uint256 _assignmentId) external {
        if (assignments[_assignmentId].worker != msg.sender)
            revert("Only assigned worker can seize the role");
        uint256 inferId = assignments[_assignmentId].inferenceId;
        if (inferences[inferId].processedMiner != address(0))
            revert("This inference has been seized");

        assignments[_assignmentId].role = AssignmentRole.Mining;
        inferences[inferId].processedMiner = msg.sender;

        emit MinerRoleSeized(_assignmentId, inferId, msg.sender);
    }

    // After listen to the new assignment, miner will call this getter to get the assignment role
    function getRoleByAssigmentId(
        uint256 _assignmentId
    ) external view returns (AssignmentRole) {
        return assignments[_assignmentId].role;
    }

    // this internal function update new epoch
    function _updateEpoch() internal {
        if (blocksPerEpoch > 0) {
            uint256 epochPassed = (block.number - lastBlock) / blocksPerEpoch;
            if (epochPassed > 0) {
                lastBlock += blocksPerEpoch * epochPassed;
                // reward for this epoch
                // rewardPerEpoch (reward one year for 1 miner)
                // rewardPerEpoch * total miner * blocker per epoch / blocks per year
                uint256 rewardInCurrentEpoch = (rewardPerEpoch *
                    minerAddresses.size() *
                    blocksPerEpoch) / BLOCK_PER_YEAR;

                for (; epochPassed > 0; epochPassed--) {
                    rewardInEpoch[currentEpoch].totalMiner = minerAddresses
                        .size();
                    rewardInEpoch[currentEpoch]
                        .epochReward = rewardInCurrentEpoch;
                    currentEpoch++;
                }
            }
        } else {
            lastBlock = block.number;
        }
    }

    function submitSolution(
        uint256 _assigmentId,
        bytes calldata _data
    ) public virtual whenNotPaused {
        _updateEpoch();
        address _msgSender = msg.sender;
        if (_data.length == 0) revert InvalidData();

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!minerAddresses.hasValue(msg.sender)) revert InvalidMiner();

        address modelAddrOfMiner = miners[msg.sender].modelAddress;
        if (!minerAddressesByModel[modelAddrOfMiner].hasValue(msg.sender))
            revert InvalidMiner();

        Assignment memory clonedAssignments = assignments[_assigmentId];
        uint256 inferId = clonedAssignments.inferenceId;

        // Check the msg sender is the assigned miner
        if (_msgSender != clonedAssignments.worker) revert Unauthorized();
        if (clonedAssignments.role != AssignmentRole.Mining)
            revert InvalidRole();

        if (clonedAssignments.output.length != 0) revert AlreadySubmitted();

        Inference memory clonedInference = inferences[inferId];

        if (clonedInference.status != InferenceStatus.Solving) {
            revert InvalidInferenceStatus();
        }



        Inference storage inference = inferences[inferId];

        assignments[_assigmentId].output = _data; //Record the solution
        bytes32 digest = keccak256(abi.encodePacked(_data)); //Record the solution
        assignments[_assigmentId].commitment = digest;
        inference.status = InferenceStatus.Commit;
        inference.assignments.push(_assigmentId);

        if (!commitments[inferId].hasValue(digest)) {
            commitments[inferId].insert(digest);
        }
        countCommitment[digest]++;

        // todo: kelvin look at this logic
        // if (inference.assignments.length == 1) {
        //     uint256 fee = (clonedInference.value * feePercentage) /
        //         PERCENTAGE_DENOMINATOR;
        //     uint256 value = clonedInference.value - fee;
        //     TransferHelper.safeTransferNative(treasury, fee);
        //     TransferHelper.safeTransferNative(_msgSender, value);

        //     emit TransferFee(_msgSender, value, treasury, fee);
        //     emit InferenceStatusUpdate(inferId, InferenceStatus.Commit);
        // }

        emit SolutionSubmission(_msgSender, _assigmentId);
    }

    function commit(
        uint256 _assignmentId,
        bytes32 _commitment
    ) public virtual whenNotPaused {
        _updateEpoch();

        if (_commitment == 0) revert InvalidCommitment();

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!minerAddresses.hasValue(msg.sender)) revert InvalidMiner();

        address modelAddrOfMiner = miners[msg.sender].modelAddress;
        if (!minerAddressesByModel[modelAddrOfMiner].hasValue(msg.sender))
            revert InvalidMiner();

        Assignment memory clonedAssignments = assignments[_assignmentId];
        uint256 inferId = clonedAssignments.inferenceId;

        if (uint40(block.timestamp) > inferences[inferId].commitTimeout)
            revert();
        if (inferences[inferId].status != InferenceStatus.Commit) {
            revert InvalidInferenceStatus();
        }

        // Check the msg sender is the assigned miner
        if (msg.sender != clonedAssignments.worker) revert Unauthorized();
        if (clonedAssignments.role != AssignmentRole.Validating)
            revert InvalidRole();
        if (clonedAssignments.commitment != 0) revert AlreadyCommitted();

        assignments[_assignmentId].commitment = _commitment;
        inferences[inferId].assignments.push(_assignmentId);
        votingInfo[inferId].totalCommit++;

        // if (!commitments[inferId].hasValue(_commitment)) {
        //     commitments[inferId].insert(_commitment);
        // }
        // countCommitment[_commitment]++;

        emit CommitmentSubmission(msg.sender, _assignmentId, _commitment);

        if (
            votingInfo[inferId].totalCommit ==
            assignmentsByInference[inferId].size() - 1
        ) {
            inferences[inferId].status = InferenceStatus.Reveal;
            emit InferenceStatusUpdate(inferId, InferenceStatus.Reveal);
        }
    }

    function reveal(
        uint256 _assignmentId,
        uint40 _nonce,
        bytes memory _data
    ) public virtual whenNotPaused {
        _updateEpoch();

        if (_data.length == 0) revert InvalidData();
        if (_nonce == 0) revert InvalidNonce();
        if (assignments[_assignmentId].revealNonce != 0)
            revert AlreadyRevealed();

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!minerAddresses.hasValue(msg.sender)) revert InvalidMiner();

        address modelAddrOfMiner = miners[msg.sender].modelAddress;
        if (!minerAddressesByModel[modelAddrOfMiner].hasValue(msg.sender))
            revert InvalidMiner();

        Assignment memory clonedAssignments = assignments[_assignmentId];
        uint256 inferId = clonedAssignments.inferenceId;

        if (uint40(block.timestamp) > inferences[inferId].revealTimeout)
            revert();
        if (inferences[inferId].status == InferenceStatus.Commit) {
            inferences[inferId].status = InferenceStatus.Reveal;
        } else if (inferences[inferId].status != InferenceStatus.Reveal) {
            revert InvalidInferenceStatus();
        }

        // Check the msg sender is the assigned miner
        if (msg.sender != clonedAssignments.worker) revert Unauthorized();
        if (clonedAssignments.role != AssignmentRole.Validating)
            revert InvalidRole();
        if (clonedAssignments.commitment == 0) revert NotCommitted();

        bytes32 commitment = clonedAssignments.commitment;
        bytes32 revealHash = keccak256(
            abi.encodePacked(_nonce, msg.sender, _data)
        );

        if (commitment != revealHash) revert InvalidReveal();

        bytes32 digest = keccak256(abi.encodePacked(_data));
        // find inference from assignment id
        uint256 firstAssignmentId = inferences[inferId].assignments[0];
        bytes32 firstAssignmentCommitment = assignments[firstAssignmentId]
            .commitment;
        if (firstAssignmentCommitment != digest) {
            assignments[_assignmentId].vote = Vote.Disapproval;
        } else {
            assignments[_assignmentId].vote = Vote.Approval;
        }

        assignments[_assignmentId].revealNonce = _nonce;
        assignments[_assignmentId].output = _data;
        assignments[_assignmentId].digest = digest;
        votingInfo[inferId].totalReveal++;

        if (!commitments[inferId].hasValue(digest)) {
            commitments[inferId].insert(digest);
        }
        countCommitment[digest]++;

        emit RevealSubmission(msg.sender, _assignmentId, _nonce, _data);

        if (
            votingInfo[inferId].totalReveal == votingInfo[inferId].totalCommit
        ) {
            resolveInference(inferId);
        }
    }

    function slashMiner(
        address _miner,
        bool _isFined
    ) public virtual onlyOwner {
        _updateEpoch();

        if (_miner == address(0)) revert InvalidMiner();

        _slashMiner(_miner, _isFined);
    }

    function _slashMiner(address _miner, bool _isFined) internal {
        Worker storage miner = miners[_miner];

        if (!minerAddresses.hasValue(_miner)) revert InvalidMiner();
        // update reward
        _claimReward(_miner, false);
        boost[_miner].reserved1 +=
            uint48(block.timestamp) -
            uint48(
                boost[_miner].minerTimestamp == 0
                    ? 1716046859
                    : boost[_miner].minerTimestamp
            );
        boost[_miner].minerTimestamp = uint40(block.timestamp);
        address modelAddress = miner.modelAddress;

        // Remove miner from available miner
        if (minerAddressesByModel[modelAddress].hasValue(_miner)) {
            minerAddressesByModel[modelAddress].erase(_miner);
            minerAddresses.erase(_miner);
        }

        // Set the time miner can join again
        miner.activeTime = uint40(block.timestamp + penaltyDuration);

        if (_isFined) {
            uint256 fine = (miner.stake * finePercentage) /
                PERCENTAGE_DENOMINATOR; // Fine = stake * 5%
            miner.stake -= fine;

            // reset boost
            boost[_miner].reserved1 = 0;
            TransferHelper.safeTransferNative(treasury, fine);

            emit FraudulentMinerPenalized(_miner, modelAddress, treasury, fine);
            return;
        }

        emit MinerDeactivated(_miner, modelAddress, miner.activeTime);
    }

    function setFinePercentage(
        uint16 _finePercentage
    ) public virtual onlyOwner {
        _updateEpoch();

        emit FinePercentageUpdated(finePercentage, _finePercentage);

        finePercentage = _finePercentage;
    }

    function setPenaltyDuration(
        uint40 _penaltyDuration
    ) public virtual onlyOwner {
        _updateEpoch();

        emit PenaltyDurationUpdated(penaltyDuration, _penaltyDuration);

        penaltyDuration = _penaltyDuration;
    }

    function enoughCommitReveal(
        uint256 _inferenceId
    ) public view returns (bool, bool) {
        return (
            votingInfo[_inferenceId].totalCommit >= votingRequirement,
            votingInfo[_inferenceId].totalReveal >= votingRequirement
        );
    }

    function _findMostVotedCommitment(
        uint256 _inferenceId
    ) internal view returns (bytes32, uint8) {
        uint8 maxCount = 0;
        bytes32 mostVotedCommitment = 0;
        bytes32[] memory commits = commitments[_inferenceId].values;
        uint256 len = commitments[_inferenceId].size();

        for (uint256 i = 0; i < len; i++) {
            bytes32 currCommit = commits[i];
            uint8 count = countCommitment[currCommit];
            if (count > maxCount) {
                maxCount = count;
                mostVotedCommitment = currCommit;
            }
        }
        return (mostVotedCommitment, maxCount);
    }

    function _filterCommitment(uint256 _inferenceId) internal returns (bool) {
        bytes32 mostVotedCommitment;
        uint8 maxCount;
        (mostVotedCommitment, maxCount) = _findMostVotedCommitment(
            _inferenceId
        );

        // Check the maxCount is greater than the voting requirement
        if (
            maxCount <
            _getThresholdValue(assignmentsByInference[_inferenceId].size())
        ) {
            return false;
        }

        uint256[] memory assignmentIds = inferences[_inferenceId].assignments;
        uint256 len = assignmentIds.length;

        //TODO: mr Issac check this logic
        bool isMatchMinerResult;
        if (assignments[assignmentIds[0]].commitment == mostVotedCommitment) {
            isMatchMinerResult = true;
        }

        uint feeForMiner = 0;
        if (isMatchMinerResult) {
            feeForMiner = inferences[_inferenceId].value * feeRatioMinerValidator / 1e4;
            TransferHelper.safeTransferNative(
                inferences[_inferenceId].processedMiner,
                feeForMiner
            );
        }

        for (uint256 i = 0; i < len; i++) {
            uint256 asgId = assignmentIds[i];
            if (assignments[asgId].commitment != mostVotedCommitment) {
                assignments[asgId].vote = Vote.Disapproval;
                _slashMiner(
                    assignments[asgId].worker,
                    assignments[asgId].worker ==
                        inferences[_inferenceId].processedMiner
                );
            } else {
                assignments[asgId].vote = Vote.Approval;
                if (!isMatchMinerResult) {
                    TransferHelper.safeTransferNative(
                        assignments[asgId].worker,
                        (inferences[_inferenceId].value - feeForMiner) / maxCount
                    );
                }
            }
        }

        return true;
    }

    function setFeeRatioMinerValidator(uint16 _newRatio) external onlyOwner {
        require(_newRatio <= 10000, "Fee ratio must be <= 10000");
        feeRatioMinerValidator = _newRatio;
    }

    function resolveInference(
        uint256 _inferenceId
    ) public virtual whenNotPaused {
        _updateEpoch();

        Inference storage inference = inferences[_inferenceId];

        if (
            inference.status == InferenceStatus.Solving &&
            inference.submitTimeout < block.timestamp &&
            inference.processedMiner != address(0)
        ) {
            inference.status = InferenceStatus.Killed;
            TransferHelper.safeTransferNative(
                inference.creator,
                inference.value
            );

            // slash miner
            _slashMiner(inference.processedMiner, true);
        }

        if (
            inference.status == InferenceStatus.Commit &&
            inference.commitTimeout < block.timestamp
        ) {
            // if 2/3 miners approve, then move to reveal phase
            if (
                votingInfo[_inferenceId].totalCommit >=
                _getThresholdValue(assignmentsByInference[_inferenceId].size())
            ) {
                inference.status == InferenceStatus.Reveal;
            } else {
                // else slash miner has not submitted solution and use miner's answer as result
                // Processed
                inference.status = InferenceStatus.Processed;
                TransferHelper.safeTransferNative(
                    inference.processedMiner,
                    inference.value
                );

                // slash miner not submitted commit hash
                uint256[] memory assignmentIds = assignmentsByInference[
                    _inferenceId
                ].values;
                for (uint i; i < assignmentIds.length; i++) {
                    //
                    if (
                        assignments[assignmentIds[i]].commitment == bytes32(0)
                    ) {
                        _slashMiner(
                            assignments[assignmentIds[i]].worker,
                            false
                        );
                    }
                }
            }
        }

        if (
            inference.status == InferenceStatus.Reveal &&
            inference.revealTimeout < block.timestamp
        ) {
            // call kelvin function to get result
            // if 2/3 miners approve, then mark this infer as processed and trigger resolve infer again
            // else slash miner has not submitted solution and use miner's answer as result
            if (!_filterCommitment(_inferenceId)) {
                // else slash miner has not submitted solution and use miner's answer as result
                // Processed
                TransferHelper.safeTransferNative(
                    inference.processedMiner,
                    inference.value
                );

                // slash miner not submitted commit hash
                uint256[] memory assignmentIds = assignmentsByInference[
                    _inferenceId
                ].values;
                for (uint i; i < assignmentIds.length; i++) {
                    //
                    if (assignments[assignmentIds[i]].revealNonce == 0) {
                        _slashMiner(
                            assignments[assignmentIds[i]].worker,
                            false
                        );
                    }
                }
            }
            inference.status = InferenceStatus.Processed;
        }

        emit InferenceStatusUpdate(_inferenceId, inference.status);
    }

    function _getThresholdValue(uint x) internal pure returns (uint) {
        return (x * 2) / 3 + (x % 3 == 0 ? 0 : 1);
    }

    function _claimReward(
        address _miner,
        bool _isTransfer
    ) internal whenNotPaused {
        uint256 rewardAmount = rewardToClaim(_miner);
        miners[_miner].lastClaimedEpoch = currentEpoch;
        if (rewardAmount > 0 && _isTransfer) {
            minerRewards[_miner] = 0;
            TransferHelper.safeTransferNative(_miner, rewardAmount);

            emit RewardClaim(_miner, rewardAmount);
        } else if (rewardAmount > 0) {
            minerRewards[_miner] = rewardAmount;
        }
    }

    // miner claim reward
    function claimReward(address _miner) public virtual nonReentrant {
        _claimReward(_miner, true);
    }

    // @dev admin functions
    function setNewRewardInEpoch(
        uint256 _newRewardAmount
    ) public virtual onlyOwner {
        _updateEpoch();
        emit RewardPerEpoch(rewardPerEpoch, _newRewardAmount);

        rewardPerEpoch = _newRewardAmount;
    }

    function setBlocksPerEpoch(uint256 _blocks) public virtual onlyOwner {
        _updateEpoch();
        if (_blocks == 0) revert InvalidBlockValue();

        emit BlocksPerEpoch(blocksPerEpoch, _blocks);

        blocksPerEpoch = _blocks;
    }

    function setUnstakDelayTime(
        uint40 _newUnstakeDelayTime
    ) public virtual onlyOwner {
        _updateEpoch();

        require(_newUnstakeDelayTime != 0, "invalid unstake delay time");

        emit UnstakeDelayTime(unstakeDelayTime, _newUnstakeDelayTime);

        unstakeDelayTime = _newUnstakeDelayTime;
    }

    // sum reward of an miner since last claimed epoch
    function rewardToClaim(address _miner) public virtual returns (uint256) {
        _updateEpoch();

        uint256 totalReward;
        uint256 lastEpoch = currentEpoch;
        if (
            !minerAddresses.hasValue(_miner) ||
            lastEpoch <= miners[_miner].lastClaimedEpoch
        ) {
            totalReward = 0;
        } else {
            uint256 lastClaimed = uint256(miners[_miner].lastClaimedEpoch);
            uint256 epochReward = (rewardPerEpoch * blocksPerEpoch) /
                BLOCK_PER_YEAR; // reward per miner in 1 epoch
            totalReward +=
                ((lastEpoch - lastClaimed) * epochReward * multiplier(_miner)) /
                PERCENTAGE_DENOMINATOR;
        }

        return totalReward + minerRewards[_miner];
    }

    function multiplier(address _miner) public view returns (uint256) {
        uint256 minerLastTimestamp;

        if (
            minerAddresses.hasValue(_miner) && boost[_miner].minerTimestamp == 0
        ) {
            minerLastTimestamp = 1716046859;
        } else if (!minerAddresses.hasValue(_miner)) {
            minerLastTimestamp = block.timestamp;
        } else {
            minerLastTimestamp = boost[_miner].minerTimestamp;
        }
        uint256 multiplierRes = (boost[_miner].reserved1 +
            block.timestamp -
            minerLastTimestamp) / 30 days;

        return
            PERCENTAGE_DENOMINATOR +
            500 *
            (multiplierRes >= 12 ? 12 : multiplierRes);
    }

    function getAllMiners() external view returns (Worker[] memory minerData) {
        address[] memory addresses = minerAddresses.values;
        minerData = new Worker[](addresses.length);
        for (uint i = 0; i < addresses.length; ++i) {
            minerData[i] = miners[addresses[i]];
        }
    }

    function getAllMinerUnstakeRequests()
        external
        view
        returns (
            address[] memory unstakeAddresses,
            UnstakeRequest[] memory unstakeRequests
        )
    {
        address[] memory addresses = minerAddresses.values;

        uint countUnstakeRequest = 0;
        for (uint i = 0; i < addresses.length; ++i) {
            UnstakeRequest memory request = minerUnstakeRequests[addresses[i]];
            if (request.unlockAt > 0) ++countUnstakeRequest;
        }

        unstakeAddresses = new address[](countUnstakeRequest);
        unstakeRequests = new UnstakeRequest[](countUnstakeRequest);
        uint idx = 0;
        for (uint i = 0; i < addresses.length; ++i) {
            UnstakeRequest memory request = minerUnstakeRequests[addresses[i]];
            if (request.unlockAt > 0) {
                unstakeAddresses[idx] = addresses[idx];
                unstakeRequests[idx] = request;
                ++idx;
            }
        }
    }

    function getAllInferences(
        uint startId,
        uint count
    ) external view returns (Inference[] memory inferenceData) {
        inferenceData = new Inference[](count);
        for (uint i = 0; i < count; ++i) {
            uint id = startId + i;
            inferenceData[i] = inferences[id];
        }
    }

    function getAllAssignments(
        uint startId,
        uint count
    ) external view returns (Assignment[] memory assignmentData) {
        assignmentData = new Assignment[](count);
        for (uint i = 0; i < count; ++i) {
            uint id = startId + i;
            assignmentData[i] = assignments[id];
        }
    }
}

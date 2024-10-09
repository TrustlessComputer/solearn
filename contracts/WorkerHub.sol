// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Random} from "./lib/Random.sol";
import {Set} from "./lib/Set.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {WorkerHubStorage} from "./storages/WorkerHubStorage.sol";
import {IDAOToken} from "./tokens/IDAOToken.sol";
import {console} from "hardhat/console.sol";

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
        address _l2Owner,
        address _treasury,
        address _daoToken,
        uint16 _feeL2Percentage,
        uint16 _feeTreasuryPercentage,
        uint256 _minerMinimumStake,
        uint8 _minerRequirement,
        uint256 _blocksPerEpoch,
        uint256 _rewardPerEpoch,
        uint40 _submitDuration,
        uint40 _commitDuration,
        uint40 _revealDuration,
        uint40 _unstakeDelayTime,
        uint40 _penaltyDuration,
        uint16 _finePercentage,
        uint16 _feeRatioMinerValidor,
        uint256 _minFeeToUse,
        uint256 _daoTokenReward,
        DAOTokenPercentage memory _daoTokenPercentage
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        require(
            _l2Owner != address(0) &&
                _treasury != address(0) &&
                _daoToken != address(0),
            "Zero address"
        );

        l2Owner = _l2Owner;
        treasury = _treasury;
        daoToken = _daoToken;
        feeL2Percentage = _feeL2Percentage;
        feeTreasuryPercentage = _feeTreasuryPercentage;
        feeRatioMinerValidator = _feeRatioMinerValidor;
        minerMinimumStake = _minerMinimumStake;
        minerRequirement = _minerRequirement;
        blocksPerEpoch = _blocksPerEpoch;
        rewardPerEpoch = _rewardPerEpoch;
        submitDuration = _submitDuration;
        commitDuration = _commitDuration;
        revealDuration = _revealDuration;
        unstakeDelayTime = _unstakeDelayTime;
        maximumTier = 1;
        lastBlock = block.number;
        penaltyDuration = _penaltyDuration;
        finePercentage = _finePercentage;
        minFeeToUse = _minFeeToUse;
        daoTokenReward = _daoTokenReward;

        setDAOTokenPercentage(_daoTokenPercentage);
    }

    function _validateDaoTokenPercentage(
        DAOTokenPercentage memory _daoTokenPercentage
    ) internal pure returns (bool) {
        return (_daoTokenPercentage.minerPercentage +
            _daoTokenPercentage.userPercentage +
            _daoTokenPercentage.referrerPercentage +
            _daoTokenPercentage.refereePercentage +
            _daoTokenPercentage.l2OwnerPercentage ==
            PERCENTAGE_DENOMINATOR);
    }

    function setDAOTokenPercentage(
        DAOTokenPercentage memory _daoTokenPercentage
    ) public onlyOwner {
        require(
            _validateDaoTokenPercentage(_daoTokenPercentage),
            "Invalid DAO Token Percentage"
        );
        emit DAOTokenPercentageUpdated(daoTokenPercentage, _daoTokenPercentage);
        daoTokenPercentage = _daoTokenPercentage;
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
                inference.submitTimeout,
                inference.commitTimeout,
                inference.revealTimeout
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

        if (_model == address(0)) revert InvalidModel();
        if (_minimumFee < minFeeToUse) revert FeeTooLow(); // NOTE: the minimum fee of using this model is 0.1 EAI
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

    function _registerReferrer(address _referrer, address _referee) internal {
        require(
            _referrer != address(0) && _referee != address(0),
            "Zero address"
        );
        require(referrerOf[_referee] == address(0), "Already registered");
        referrerOf[_referee] = _referrer;
    }

    function registerReferrer(address _referrer) external {
        _updateEpoch();
        _registerReferrer(_referrer, msg.sender);
    }

    function registerReferrer(
        address[] memory _referrers,
        address[] memory _referees
    ) external onlyOwner {
        _updateEpoch();
        require(_referrers.length == _referees.length, "Invalid input");
        for (uint256 i = 0; i < _referrers.length; i++) {
            _registerReferrer(_referrers[i], _referees[i]);
        }
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
            uint40(block.number + unstakeDelayTime)
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
        if (block.number < unstakeRequest.unlockAt) revert StillBeingLocked();

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
        uint256 feeL2 = (value * feeL2Percentage) / PERCENTAGE_DENOMINATOR;
        uint256 feeTreasury = (value * feeTreasuryPercentage) /
            PERCENTAGE_DENOMINATOR;

        inference.input = _input;
        inference.feeL2 = feeL2;
        inference.feeTreasury = feeTreasury;
        inference.value = value - feeL2 - feeTreasury;
        inference.creator = _creator;
        inference.referrer = referrerOf[_creator];
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
        uint40 expiredAt = uint40(block.number + submitDuration);
        uint40 commitTimeout = expiredAt + commitDuration;
        inferences[_inferenceId].submitTimeout = expiredAt;
        inferences[_inferenceId].commitTimeout = commitTimeout;
        inferences[_inferenceId].revealTimeout = commitTimeout + revealDuration;
        inferences[_inferenceId].status = InferenceStatus.Solving;

        address model = inferences[_inferenceId].modelAddress;
        if (minerAddressesByModel[model].size() < minerRequirement)
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
        _updateEpoch();

        if (assignments[_assignmentId].worker != msg.sender)
            revert("Only assigned worker can seize the role");
        uint256 inferId = assignments[_assignmentId].inferenceId;
        if (inferences[inferId].processedMiner != address(0))
            revert("This inference has been seized");

        assignments[_assignmentId].role = AssignmentRole.Mining;
        inferences[inferId].processedMiner = msg.sender;

        emit MinerRoleSeized(_assignmentId, inferId, msg.sender);
    }

    // After listen to the new assignment, miner can call this getter to get the assignment role
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
        assignments[_assigmentId].digest = digest;
        assignments[_assigmentId].commitment = digest;
        inference.status = InferenceStatus.Commit;
        inference.assignments.push(_assigmentId);

        if (!digests[inferId].hasValue(digest)) {
            digests[inferId].insert(digest);
        }
        countDigest[digest]++;

        emit InferenceStatusUpdate(inferId, InferenceStatus.Commit);
        emit SolutionSubmission(_msgSender, _assigmentId);
    }

    modifier onlyActiveWorker() {
        _checkWorkerAvailable(msg.sender);
        _;
    }

    function _checkWorkerAvailable(address _workerAddr) internal view {
        // Check whether miner is available (the miner had previously joined and still work to serve or the assigned model).
        if (!minerAddresses.hasValue(_workerAddr)) revert InvalidMiner();

        address modelAddrOfMiner = miners[_workerAddr].modelAddress;
        if (!minerAddressesByModel[modelAddrOfMiner].hasValue(_workerAddr))
            revert InvalidMiner();
    }

    function commit(
        uint256 _assignId,
        bytes32 _commitment
    ) public virtual whenNotPaused {
        _updateEpoch();

        if (_commitment == 0) revert InvalidCommitment();

        Assignment storage assignment = assignments[_assignId];
        uint256 inferId = assignment.inferenceId;
        Inference storage inference = inferences[inferId];

        if (uint40(block.number) > inference.commitTimeout)
            revert CommitTimeout();
        if (inference.status != InferenceStatus.Commit) {
            revert InvalidInferenceStatus();
        }

        // Check the msg sender is the assigned miner
        if (msg.sender != assignment.worker) revert Unauthorized();
        if (assignment.role != AssignmentRole.Validating) revert InvalidRole();
        if (assignment.commitment != 0) revert AlreadyCommitted();

        assignment.commitment = _commitment;
        inference.assignments.push(_assignId);
        votingInfo[inferId].totalCommit++;

        emit CommitmentSubmission(msg.sender, _assignId, _commitment);

        if (
            votingInfo[inferId].totalCommit ==
            assignmentsByInference[inferId].size() - 1
        ) {
            inference.status = InferenceStatus.Reveal;
            emit InferenceStatusUpdate(inferId, InferenceStatus.Reveal);
        }
    }

    function reveal(
        uint256 _assignId,
        uint40 _nonce,
        bytes memory _data
    ) public virtual whenNotPaused {
        _updateEpoch();

        if (_data.length == 0) revert InvalidData();
        if (_nonce == 0) revert InvalidNonce();

        Assignment storage assignment = assignments[_assignId];
        if (assignment.revealNonce != 0) revert AlreadyRevealed();

        uint256 inferId = assignment.inferenceId;
        Inference storage inference = inferences[inferId];

        if (uint40(block.number) > inference.revealTimeout)
            revert RevealTimeout();
        if (inference.status == InferenceStatus.Commit) {
            inference.status = InferenceStatus.Reveal;
        } else if (inference.status != InferenceStatus.Reveal) {
            revert InvalidInferenceStatus();
        }

        // Check the msg sender is the assigned miner
        if (msg.sender != assignment.worker) revert Unauthorized();
        if (assignment.role != AssignmentRole.Validating) revert InvalidRole();
        if (assignment.commitment == 0) revert NotCommitted();

        bytes32 commitment = assignment.commitment;
        bytes32 revealHash = keccak256(
            abi.encodePacked(_nonce, msg.sender, _data)
        );

        if (commitment != revealHash) revert InvalidReveal();
        bytes32 digest = keccak256(abi.encodePacked(_data));

        assignment.revealNonce = _nonce;
        assignment.output = _data;
        assignment.digest = digest;
        votingInfo[inferId].totalReveal++;

        if (!digests[inferId].hasValue(digest)) {
            digests[inferId].insert(digest);
        }
        countDigest[digest]++;

        emit RevealSubmission(msg.sender, _assignId, _nonce, _data);

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
            uint256 fine = (minerMinimumStake * finePercentage) /
                PERCENTAGE_DENOMINATOR; // Fine = stake * 10%
            if (miner.stake < fine) {
                miner.stake = 0;
            } else {
                miner.stake -= fine;
            }

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

    function setMinFeeToUse(uint256 _minFeeToUse) public virtual onlyOwner {
        _updateEpoch();

        emit MinFeeToUseUpdated(minFeeToUse, _minFeeToUse);

        minFeeToUse = _minFeeToUse;
    }

    function setL2Owner(address _l2OwnerAddress) public virtual onlyOwner {
        require(_l2OwnerAddress != address(0), "Zero address");
        _updateEpoch();

        emit L2OwnerUpdated(l2Owner, _l2OwnerAddress);

        l2Owner = _l2OwnerAddress;
    }

    function setDAOToken(address _daoTokenAddress) public virtual onlyOwner {
        require(_daoTokenAddress != address(0), "Zero address");
        _updateEpoch();

        emit DAOTokenUpdated(daoToken, _daoTokenAddress);

        daoToken = _daoTokenAddress;
    }

    function setTreasuryAddress(
        address _treasuryAddress
    ) public virtual onlyOwner {
        require(_treasuryAddress != address(0), "Zero address");
        _updateEpoch();

        emit TreasuryAddressUpdated(treasury, _treasuryAddress);

        treasury = _treasuryAddress;
    }

    function _transferDAOToken(
        uint256 chainID,
        address modelAddress,
        uint256 _inferenceId,
        bool _isReferred
    ) internal {
        DAOTokenPercentage memory percentage = daoTokenPercentage;
        address referrer = inferences[_inferenceId].referrer;
        DAOTokenReceiverInfor[] memory receiverInfors;

        if (_isReferred) {
            uint256 l2OwnerAmt = (daoTokenReward *
                percentage.l2OwnerPercentage) / PERCENTAGE_DENOMINATOR;
            uint256 userAmt = (daoTokenReward *
                (percentage.refereePercentage + percentage.userPercentage)) /
                PERCENTAGE_DENOMINATOR;
            uint256 refererAmt = (daoTokenReward *
                percentage.referrerPercentage) / PERCENTAGE_DENOMINATOR;

            IDAOToken(daoToken).mint(l2Owner, l2OwnerAmt);
            IDAOToken(daoToken).mint(inferences[_inferenceId].creator, userAmt);
            IDAOToken(daoToken).mint(referrer, refererAmt);

            receiverInfors = new DAOTokenReceiverInfor[](3);
            receiverInfors[0] = DAOTokenReceiverInfor(
                l2Owner,
                l2OwnerAmt,
                DAOTokenReceiverRole.L2Owner
            );
            receiverInfors[1] = DAOTokenReceiverInfor(
                inferences[_inferenceId].creator,
                userAmt,
                DAOTokenReceiverRole.User
            );
            receiverInfors[2] = DAOTokenReceiverInfor(
                referrer,
                refererAmt,
                DAOTokenReceiverRole.Referrer
            );
        } else {
            uint256 l2OwnerAmt = (daoTokenReward *
                percentage.l2OwnerPercentage) / PERCENTAGE_DENOMINATOR;
            uint256 userAmt = (daoTokenReward * percentage.userPercentage) /
                PERCENTAGE_DENOMINATOR;

            IDAOToken(daoToken).mint(l2Owner, l2OwnerAmt);
            IDAOToken(daoToken).mint(inferences[_inferenceId].creator, userAmt);

            receiverInfors = new DAOTokenReceiverInfor[](2);
            receiverInfors[0] = DAOTokenReceiverInfor(
                l2Owner,
                l2OwnerAmt,
                DAOTokenReceiverRole.L2Owner
            );
            receiverInfors[1] = DAOTokenReceiverInfor(
                inferences[_inferenceId].creator,
                userAmt,
                DAOTokenReceiverRole.User
            );
        }
        emit DAOTokenMintedV2(
            chainID,
            _inferenceId,
            modelAddress,
            receiverInfors
        );
        console.log("Minted DAO Token");
    }

    function _getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _findMostVotedDigest(
        uint256 _inferenceId
    ) internal view returns (bytes32, uint8) {
        uint8 maxCount = 0;
        bytes32 mostVotedDigest = 0;
        bytes32[] memory digestArr = digests[_inferenceId].values;
        uint256 len = digests[_inferenceId].size();

        for (uint256 i = 0; i < len; i++) {
            bytes32 currDigest = digestArr[i];
            uint8 count = countDigest[currDigest];
            if (count > maxCount) {
                maxCount = count;
                mostVotedDigest = currDigest;
            }
        }
        return (mostVotedDigest, maxCount);
    }

    function getFilterCommitment1(
        uint256 _inferenceId
    ) external returns (bool) {
        (bytes32 mostVotedDigest, uint8 maxCount) = _findMostVotedDigest(
            _inferenceId
        );

        // Check the maxCount is greater than the voting requirement
        if (
            maxCount <
            _getThresholdValue(assignmentsByInference[_inferenceId].size())
        ) {
            return false;
        }

        return true;
    }

    function findMostVotedDigest(
        uint256 _inferenceId
    ) external view returns (bytes32, uint8) {
        return _findMostVotedDigest(_inferenceId);
    }

    // function getFilterCommitment(
    //     uint256 _inferenceId
    // ) external view returns (bool, address[] memory, uint256[] memory) {
    //     (bytes32 mostVotedDigest, uint8 maxCount) = _findMostVotedDigest(
    //         _inferenceId
    //     );

    //     // Check the maxCount is greater than the voting requirement
    //     if (
    //         maxCount <
    //         _getThresholdValue(assignmentsByInference[_inferenceId].size())
    //     ) {
    //         return (false, new address[](0), new uint256[](0));
    //     }

    //     bool notReachedLimit;
    //     bool isReferred = inferences[_inferenceId].referrer != address(0);
    //     if (isReferred) {
    //         notReachedLimit = IDAOToken(daoToken).validateSupplyIncrease(
    //             daoTokenReward
    //         );
    //     } else {
    //         notReachedLimit = IDAOToken(daoToken).validateSupplyIncrease(
    //             (daoTokenReward *
    //                 (PERCENTAGE_DENOMINATOR -
    //                     daoTokenPercentage.referrerPercentage -
    //                     daoTokenPercentage.refereePercentage)) /
    //                 PERCENTAGE_DENOMINATOR
    //         );
    //     }

    //     uint256[] memory assignmentIds = inferences[_inferenceId].assignments;
    //     uint256 len = assignmentIds.length;
    //     bool isMatchMinerResult = assignments[assignmentIds[0]].digest ==
    //         mostVotedDigest;

    //     //EAI
    //     uint256 feeForMiner = 0;
    //     uint256 shareFeePerValidator = 0;
    //     uint256 remainValue = inferences[_inferenceId].value;
    //     // DAO token
    //     uint256 tokenForMiner = 0;
    //     uint256 shareTokenPerValidator = 0;
    //     uint256 remainToken = (daoTokenPercentage.minerPercentage *
    //         380000000000000000) / PERCENTAGE_DENOMINATOR;

    //     // Transsffer DAO token to l2 owner, user and referrer
    //     address modelAddress = inferences[_inferenceId].modelAddress;
    //     uint256 chainId = _getChainID();
    //     address[] memory addresses;
    //     uint256[] memory amounts;
    //     if (notReachedLimit && remainToken > 0) {
    //         (addresses, amounts) = get_transferDAOToken(
    //             chainId,
    //             modelAddress,
    //             _inferenceId,
    //             isReferred
    //         );
    //         return (true, addresses, amounts);
    //     }

    //     // Calculate fee for miner and share fee for validators
    //     if (isMatchMinerResult) {
    //         //if miner result is correct, then fee for miner = feeRatioMinerValidator * remainValue / 10000
    //         feeForMiner =
    //             (remainValue * feeRatioMinerValidator) /
    //             PERCENTAGE_DENOMINATOR;
    //         shareFeePerValidator = (remainValue - feeForMiner) / (maxCount - 1);
    //         tokenForMiner =
    //             (remainToken * feeRatioMinerValidator) /
    //             PERCENTAGE_DENOMINATOR;
    //         shareTokenPerValidator =
    //             (remainToken - tokenForMiner) /
    //             (maxCount - 1);
    //     } else {
    //         //if miner result is incorrect, then fee for miner = 0 and all honest validators will share the remainValue
    //         shareFeePerValidator = remainValue / maxCount;
    //         shareTokenPerValidator = remainToken / maxCount;
    //     }
    //     address[] memory addresses1;
    //     uint256[] memory amounts1;
    //     uint8 counter = 0;

    //     for (uint256 i = 0; i < len; i++) {
    //         Assignment storage assignment = assignments[assignmentIds[i]];
    //         // Logically, when a worker calls the commit function, it proves that the worker is active.
    //         // Calling the reveal function is a natural consequence if the worker is honest.
    //         // Therefore, if a worker calls commit but doesn't call reveal, it is highly likely that they are dishonest,
    //         // leading to the decision to slash this worker.
    //         if (assignment.digest != mostVotedDigest) {
    //             // assignment.vote = Vote.Disapproval;
    //             // _slashMiner(assignment.worker, true); // Slash dishonest workers (miner and validators will be slashed in the same way)
    //         } else {
    //             // process for honest workers
    //             // assignment.vote = Vote.Approval;
    //             if (assignment.role == AssignmentRole.Validating) {
    //                 // if it iss validator, then transfer share fee
    //                 if (shareFeePerValidator > 0) {
    //                     // TransferHelper.safeTransferNative(
    //                     //     assignment.worker,
    //                     //     shareFeePerValidator
    //                     // );
    //                 }
    //                 if (notReachedLimit && tokenForMiner > 0) {
    //                     addresses1[counter] = assignment.worker;
    //                     amounts1[counter] = shareTokenPerValidator;
    //                     counter++;
    //                 }
    //             } else {
    //                 if (feeForMiner > 0) {
    //                     // it is miner, if miner is honest, the feeForMiner is greater than 0
    //                     // TransferHelper.safeTransferNative(
    //                     //     assignment.worker,
    //                     //     feeForMiner
    //                     // );
    //                 }
    //                 if (notReachedLimit && tokenForMiner > 0) {
    //                     addresses1[counter] = assignment.worker;
    //                     amounts1[counter] = tokenForMiner;
    //                     counter++;
    //                 }
    //             }
    //         }
    //     }

    //     return (true, addresses1, amounts1);
    // }

    // function get_transferDAOToken(
    //     uint256 chainID,
    //     address modelAddress,
    //     uint256 _inferenceId,
    //     bool _isReferred
    // ) internal view returns (address[] memory, uint256[] memory) {
    //     DAOTokenPercentage memory percentage = daoTokenPercentage;
    //     address referrer = inferences[_inferenceId].referrer;
    //     address[] memory addresses;
    //     uint256[] memory amounts;

    //     addresses[0] = l2Owner;
    //     addresses[1] = inferences[_inferenceId].creator;
    //     amounts[0] =
    //         (daoTokenReward * percentage.l2OwnerPercentage) /
    //         PERCENTAGE_DENOMINATOR;

    //     if (_isReferred) {
    //         addresses[2] = referrer;
    //         amounts[1] =
    //             (daoTokenReward *
    //                 (percentage.refereePercentage +
    //                     percentage.userPercentage)) /
    //             PERCENTAGE_DENOMINATOR;
    //         amounts[2] =
    //             (daoTokenReward * percentage.referrerPercentage) /
    //             PERCENTAGE_DENOMINATOR;
    //     } else {
    //         amounts[1] =
    //             (daoTokenReward * percentage.userPercentage) /
    //             PERCENTAGE_DENOMINATOR;
    //     }

    //     return (addresses, amounts);
    // }

    function _filterCommitment(uint256 _inferenceId) internal returns (bool) {
        (bytes32 mostVotedDigest, uint8 maxCount) = _findMostVotedDigest(
            _inferenceId
        );

        // Check the maxCount is greater than the voting requirement
        if (
            maxCount <
            _getThresholdValue(assignmentsByInference[_inferenceId].size())
        ) {
            return false;
        }

        bool notReachedLimit;
        bool isReferred = inferences[_inferenceId].referrer != address(0);
        if (isReferred) {
            notReachedLimit = IDAOToken(daoToken).validateSupplyIncrease(
                daoTokenReward
            );
        } else {
            notReachedLimit = IDAOToken(daoToken).validateSupplyIncrease(
                (daoTokenReward *
                    (PERCENTAGE_DENOMINATOR -
                        daoTokenPercentage.referrerPercentage -
                        daoTokenPercentage.refereePercentage)) /
                    PERCENTAGE_DENOMINATOR
            );
        }
        console.log("isReferred: ", isReferred);
        console.log("notReachedLimit: ", notReachedLimit);

        uint256[] memory assignmentIds = inferences[_inferenceId].assignments;
        uint256 len = assignmentIds.length;
        bool isMatchMinerResult = assignments[assignmentIds[0]].digest ==
            mostVotedDigest;

        //EAI
        uint256 feeForMiner = 0;
        uint256 shareFeePerValidator = 0;
        uint256 remainValue = inferences[_inferenceId].value;
        // DAO token
        uint256 tokenForMiner = 0;
        uint256 shareTokenPerValidator = 0;
        uint256 remainToken = (daoTokenPercentage.minerPercentage *
            daoTokenReward) / PERCENTAGE_DENOMINATOR;

        // Transsffer DAO token to l2 owner, user and referrer
        address modelAddress = inferences[_inferenceId].modelAddress;
        uint256 chainId = _getChainID();
        console.log("notReachedLimit: ", notReachedLimit);
        console.log("remainToken: ", remainToken);
        if (notReachedLimit && remainToken > 0) {
            _transferDAOToken(chainId, modelAddress, _inferenceId, isReferred);
        }

        // Calculate fee for miner and share fee for validators
        if (isMatchMinerResult) {
            //if miner result is correct, then fee for miner = feeRatioMinerValidator * remainValue / 10000
            feeForMiner =
                (remainValue * feeRatioMinerValidator) /
                PERCENTAGE_DENOMINATOR;
            shareFeePerValidator = (remainValue - feeForMiner) / (maxCount - 1);
            tokenForMiner =
                (remainToken * feeRatioMinerValidator) /
                PERCENTAGE_DENOMINATOR;
            shareTokenPerValidator =
                (remainToken - tokenForMiner) /
                (maxCount - 1);
        } else {
            //if miner result is incorrect, then fee for miner = 0 and all honest validators will share the remainValue
            shareFeePerValidator = remainValue / maxCount;
            shareTokenPerValidator = remainToken / maxCount;
        }
        DAOTokenReceiverInfor[]
            memory receiverInfors = new DAOTokenReceiverInfor[](len);

        uint8 counter = 0;

        for (uint256 i = 0; i < len; i++) {
            Assignment storage assignment = assignments[assignmentIds[i]];
            // Logically, when a worker calls the commit function, it proves that the worker is active.
            // Calling the reveal function is a natural consequence if the worker is honest.
            // Therefore, if a worker calls commit but doesn't call reveal, it is highly likely that they are dishonest,
            // leading to the decision to slash this worker.
            if (assignment.digest != mostVotedDigest) {
                assignment.vote = Vote.Disapproval;
                _slashMiner(assignment.worker, true); // Slash dishonest workers (miner and validators will be slashed in the same way)
            } else {
                // process for honest workers
                assignment.vote = Vote.Approval;
                if (assignment.role == AssignmentRole.Validating) {
                    // if it iss validator, then transfer share fee
                    if (shareFeePerValidator > 0) {
                        TransferHelper.safeTransferNative(
                            assignment.worker,
                            shareFeePerValidator
                        );
                    }
                    if (notReachedLimit && tokenForMiner > 0) {
                        IDAOToken(daoToken).mint(
                            assignment.worker,
                            shareTokenPerValidator
                        );

                        receiverInfors[counter] = DAOTokenReceiverInfor(
                            assignment.worker,
                            shareTokenPerValidator,
                            DAOTokenReceiverRole.Validator
                        );
                        counter++;
                        console.log("counter: ", counter);
                    }
                } else {
                    if (feeForMiner > 0) {
                        // it is miner, if miner is honest, the feeForMiner is greater than 0
                        TransferHelper.safeTransferNative(
                            assignment.worker,
                            feeForMiner
                        );
                    }
                    if (notReachedLimit && tokenForMiner > 0) {
                        IDAOToken(daoToken).mint(
                            assignment.worker,
                            tokenForMiner
                        );
                        receiverInfors[counter] = DAOTokenReceiverInfor(
                            assignment.worker,
                            tokenForMiner,
                            DAOTokenReceiverRole.Miner
                        );
                        counter++;
                        console.log("counter: ", counter);
                    }
                }
            }
        }

        DAOTokenReceiverInfor[]
            memory receiverInforsClone = new DAOTokenReceiverInfor[](
                counter - 1
            );

        for (uint256 i = 0; i < counter - 1; i++) {
            receiverInforsClone[i] = receiverInfors[i];
        }

        if (notReachedLimit && remainToken > 0) {
            console.log("Minted DAO Token for minerss");
            emit DAOTokenMintedV2(
                chainId,
                _inferenceId,
                modelAddress,
                receiverInforsClone
            );
        }

        // Transfer the mining fee to treasury
        if (inferences[_inferenceId].feeL2 > 0) {
            TransferHelper.safeTransferNative(
                l2Owner,
                inferences[_inferenceId].feeL2
            );
        }
        if (inferences[_inferenceId].feeTreasury > 0) {
            TransferHelper.safeTransferNative(
                treasury,
                inferences[_inferenceId].feeTreasury
            );
        }

        return true;
    }

    function setFeeRatioMinerValidator(uint16 _newRatio) external onlyOwner {
        require(_newRatio <= 10000, "Fee ratio must be <= 10000");
        feeRatioMinerValidator = _newRatio;
    }

    function setDAOTokenReward(uint256 _newDAOTokenReward) external onlyOwner {
        // require(_newDAOTokenReward != 0, "DAOTokenReward must be > 0");
        daoTokenReward = _newDAOTokenReward;
    }

    function resolveInference(
        uint256 _inferenceId
    ) public virtual whenNotPaused {
        _updateEpoch();

        Inference storage inference = inferences[_inferenceId];

        // If the inference is not processed (not seize or not submit solution),
        // we will refund all the value that user spent to get solution
        if (
            inference.status == InferenceStatus.Solving &&
            inference.submitTimeout < block.number &&
            inference.processedMiner != address(0)
        ) {
            inference.status = InferenceStatus.Killed;
            TransferHelper.safeTransferNative(
                inference.creator,
                inference.value + inference.feeL2 + inference.feeTreasury
            );

            // slash miner
            _slashMiner(inference.processedMiner, true);
        }

        if (
            inference.status == InferenceStatus.Commit &&
            inference.commitTimeout < block.number
        ) {
            // if 2/3 miners approve, then move to reveal phase
            if (
                votingInfo[_inferenceId].totalCommit + 1 >=
                _getThresholdValue(assignmentsByInference[_inferenceId].size())
            ) {
                inference.status == InferenceStatus.Reveal;
            } else {
                // else slash miner has not submitted solution and refund to user (because we do not know the correctly result)
                // Processed
                inference.status = InferenceStatus.Processed;
                TransferHelper.safeTransferNative(
                    inference.creator,
                    inference.value + inference.feeL2 + inference.feeTreasury
                );

                // slash validator not submitted commit hash
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
            (inference.revealTimeout < block.number ||
                votingInfo[_inferenceId].totalReveal ==
                votingInfo[_inferenceId].totalCommit)
        ) {
            // call kelvin function to get result
            // if 2/3 miners approve, then mark this infer as processed and trigger resolve infer again
            // else slash miner has not submitted solution and use miner's answer as result
            if (!_filterCommitment(_inferenceId)) {
                console.log("Reveal 1");

                // edisable workers not call reveal and refund to user
                // Processed
                TransferHelper.safeTransferNative(
                    inference.creator,
                    inference.value + inference.feeL2 + inference.feeTreasury
                );

                // disable workers not call reveal
                uint256[] memory assignmentIds = assignmentsByInference[
                    _inferenceId
                ].values;
                for (uint i; i < assignmentIds.length; i++) {
                    //
                    if (assignments[assignmentIds[i]].digest == bytes32(0)) {
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

    function setSubmitDuration(
        uint40 _newSubmitDuration
    ) public virtual onlyOwner {
        _updateEpoch();

        require(_newSubmitDuration != 0, "invalid submit duration time");

        emit SubmitDuration(submitDuration, _newSubmitDuration);

        submitDuration = _newSubmitDuration;
    }

    function setCommitDuration(
        uint40 _newCommitDuration
    ) public virtual onlyOwner {
        _updateEpoch();

        require(_newCommitDuration != 0, "invalid commit duration time");

        emit CommitDuration(commitDuration, _newCommitDuration);

        commitDuration = _newCommitDuration;
    }

    function setRevealDuration(
        uint40 _newRevealDuration
    ) public virtual onlyOwner {
        _updateEpoch();

        require(_newRevealDuration != 0, "invalid reveal duration time");

        emit RevealDuration(revealDuration, _newRevealDuration);

        revealDuration = _newRevealDuration;
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

    function getInferenceInfo(
        uint256 _inferenceId
    ) external view returns (Inference memory) {
        return inferences[_inferenceId];
    }

    function getAssignmentByMiner(
        address _minerAddr
    ) external view returns (AssignmentInfo[] memory) {
        uint256[] memory assignmentIds = assignmentsByMiner[_minerAddr].values;
        uint count = assignmentIds.length;
        AssignmentInfo[] memory result = new AssignmentInfo[](count);

        for (uint i = 0; i < count; ++i) {
            Assignment storage assignment = assignments[assignmentIds[i]];
            Inference storage inference = inferences[assignment.inferenceId];

            result[i] = AssignmentInfo(
                assignmentIds[i],
                assignment.inferenceId,
                inference.value,
                inference.input,
                inference.modelAddress,
                inference.creator,
                inference.submitTimeout,
                inference.commitTimeout,
                inference.revealTimeout
            );
        }
        return result;
    }

    function isAssignmentPending(
        uint256 _assignmentId
    ) public view returns (bool) {
        return
            assignments[_assignmentId].output.length == 0 &&
            block.number <
            inferences[assignments[_assignmentId].inferenceId].revealTimeout;
    }

    function streamData(uint256 _assignmentId, bytes memory _data) external {
        require(_assignmentId <= assignmentNumber, "Invalid assignment id");
        emit StreamedData(_assignmentId, _data);
    }
}

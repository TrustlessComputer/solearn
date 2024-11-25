// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Random} from "../lib/Random.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";
import {WorkerHubStorage, IWorkerHub, Set} from "../storages/WorkerHubStorage.sol";
import {IDAOToken} from "../tokens/IDAOToken.sol";
import {IStakingHub} from "../interfaces/IStakingHub.sol";

contract WorkerHub is
    WorkerHubStorage,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using Random for Random.Randomizer;
    using Set for Set.Uint256Set;
    using Set for Set.Bytes32Set;

    string private constant VERSION = "v0.0.2";
    uint256 internal constant PERCENTAGE_DENOMINATOR = 100_00;
    uint256 private constant BLOCK_PER_YEAR = 365 days / 2; // 2s per block

    receive() external payable {}

    constructor(
        address _wEAI,
        address _l2Owner,
        address _treasury,
        address _daoToken,
        address _stakingHub,
        uint16 _feeL2Percentage,
        uint16 _feeTreasuryPercentage,
        uint8 _minerRequirement,
        uint40 _submitDuration,
        uint40 _commitDuration,
        uint40 _revealDuration,
        uint16 _feeRatioMinerValidor,
        uint256 _daoTokenReward,
        DAOTokenPercentage memory _daoTokenPercentage
    ) {
        require(
            _l2Owner != address(0) &&
                _treasury != address(0) &&
                _daoToken != address(0) &&
                _stakingHub != address(0) &&
                _wEAI != address(0),
            "Zero address"
        );

        l2Owner = _l2Owner;
        treasury = _treasury;
        daoToken = _daoToken;
        stakingHub = _stakingHub;
        feeL2Percentage = _feeL2Percentage;
        feeTreasuryPercentage = _feeTreasuryPercentage;
        feeRatioMinerValidator = _feeRatioMinerValidor;
        minerRequirement = _minerRequirement;

        daoTokenReward = _daoTokenReward;
        submitDuration = _submitDuration;
        commitDuration = _commitDuration;
        revealDuration = _revealDuration;
        daoTokenPercentage = _daoTokenPercentage;
        wEAI = _wEAI;
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

    function _registerReferrer(address _referrer, address _referee) internal {
        if (_referrer == address(0) || _referee == address(0))
            revert InvalidData();
        if (referrerOf[_referee] != address(0)) revert AlreadySubmitted();

        referrerOf[_referee] = _referrer;
    }

    function registerReferrer(
        address[] memory _referrers,
        address[] memory _referees
    ) external onlyOwner {
        if (_referrers.length != _referees.length) revert InvalidData();

        for (uint256 i = 0; i < _referrers.length; i++) {
            _registerReferrer(_referrers[i], _referees[i]);
        }
    }

    function infer(
        bytes calldata _input,
        address _creator,
        bool _flag
    ) external payable whenNotPaused returns (uint256) {
        return _infer(_input, _creator, 0, _flag);
    }

    function infer(
        bytes calldata _input,
        address _creator
    ) external payable whenNotPaused returns (uint256) {
        return _infer(_input, _creator, 0, false);
    }

    function _infer(
        bytes calldata _input,
        address _creator,
        uint256 _scoringFee,
        bool _flag
    ) internal virtual returns (uint256) {
        IStakingHub.Model memory model = IStakingHub(stakingHub).getModelInfo(
            msg.sender
        );
        if (model.tier == 0) revert Unauthorized();

        uint256 inferenceId = ++inferenceNumber;
        Inference storage inference = inferences[inferenceId];

        uint256 value = msg.value - _scoringFee;
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

        _assignMiners(inferenceId);

        emit NewInference(inferenceId, msg.sender, _creator, value, 0);
        emit RawSubmitted(
            inferenceId,
            msg.sender,
            _creator,
            value,
            0,
            _input,
            _flag
        );

        return inferenceId;
    }

    function _assignMiners(uint256 _inferenceId) internal {
        uint40 expiredAt = uint40(block.number + submitDuration);
        uint40 commitTimeout = expiredAt + commitDuration;
        inferences[_inferenceId].submitTimeout = expiredAt;
        inferences[_inferenceId].commitTimeout = commitTimeout;
        inferences[_inferenceId].revealTimeout = commitTimeout + revealDuration;
        inferences[_inferenceId].status = InferenceStatus.Solving;

        address model = inferences[_inferenceId].modelAddress;
        address[] memory miners = IStakingHub(stakingHub)
            .getMinerAddressesOfModel(model);
        uint8 index = uint8(randomizer.randomUint256() % miners.length);
        address miner = miners[index];
        uint256 assignmentId = ++assignmentNumber;
        assignments[assignmentId].inferenceId = _inferenceId;
        assignments[assignmentId].worker = miner;
        assignments[assignmentId].role = AssignmentRole.Mining;

        emit NewAssignment(assignmentId, _inferenceId, miner, expiredAt);
    }

    function _validatateSolution(bytes calldata _data) internal pure virtual {
        if (_data.length == 0) revert InvalidData();
    }

    // 0xe84dee6b
    function submitSolution(
        uint256 _assigmentId,
        bytes calldata _data
    ) external virtual whenNotPaused {
        IStakingHub(stakingHub).updateEpoch();
        _validatateSolution(_data);

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!IStakingHub(stakingHub).isMinerAddress(msg.sender))
            revert InvalidMiner();

        IStakingHub(stakingHub).validateModelOfMiner(msg.sender);

        Assignment memory clonedAssignments = assignments[_assigmentId];
        uint256 inferId = clonedAssignments.inferenceId;

        // Check the msg sender is the assigned miner
        if (msg.sender != clonedAssignments.worker) revert Unauthorized();
        if (clonedAssignments.role != AssignmentRole.Mining)
            revert InvalidRole();

        if (clonedAssignments.output.length != 0) revert AlreadySubmitted();

        Inference memory clonedInference = inferences[inferId];

        if (clonedInference.status != InferenceStatus.Solving) {
            revert InvalidInferenceStatus();
        }

        if (uint40(block.number) > clonedInference.submitTimeout)
            revert SubmitTimeout();

        Inference storage inference = inferences[inferId];

        assignments[_assigmentId].output = _data; //Record the solution
        bytes32 digest = keccak256(abi.encodePacked(inferId, _data)); //Record the solution
        assignments[_assigmentId].digest = digest;
        assignments[_assigmentId].commitment = digest;
        inference.status = InferenceStatus.Commit;
        inference.assignments.push(_assigmentId);

        if (!digests[inferId].hasValue(digest)) {
            digests[inferId].insert(digest);
        }
        countDigest[digest]++;

        emit InferenceStatusUpdate(inferId, InferenceStatus.Commit);
        emit SolutionSubmission(msg.sender, _assigmentId);
    }

    function getInferenceInfo(
        uint256 _inferenceId
    ) external view returns (Inference memory) {
        return inferences[_inferenceId];
    }

    function getAssignmentsByInference(
        uint256 _inferenceId
    ) external view returns (uint256[] memory) {
        return assignmentsByInference[_inferenceId].values;
    }

    function getAssignmentInfo(
        uint256 _assignmentId
    ) external view returns (Assignment memory) {
        return assignments[_assignmentId];
    }

      function getMinFeeToUse(
        address _modelAddress
    ) external view returns (uint256) {
        return IStakingHub(stakingHub).getMinFeeToUse(_modelAddress);
    }

    function getTreasuryAddress() external view returns (address) {
        return treasury;
    }
    
}

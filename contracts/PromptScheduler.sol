// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Random} from "./lib/Random.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {PromptSchedulerStorage, IWorkerHub, Set} from "./storages/PromptSchedulerStorage.sol";
import {IDAOToken} from "./tokens/IDAOToken.sol";
import {IStakingHub} from "./interfaces/IStakingHub.sol";

contract PromptScheduler is
    PromptSchedulerStorage,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Random for Random.Randomizer;
    using Set for Set.Uint256Set;
    using Set for Set.Bytes32Set;

    string private constant VERSION = "v0.0.2";
    uint256 internal constant PERCENTAGE_DENOMINATOR = 100_00;
    uint256 private constant BLOCK_PER_YEAR = 365 days / 2; // 2s per block

    receive() external payable {}

    function initialize(
        address _wEAI,
        address _l2Owner,
        address _treasury,
        address _daoToken,
        address _stakingHub,
        uint16 _feeL2Percentage,
        uint16 _feeTreasuryPercentage,
        uint8 _minerRequirement,
        uint40 _submitDuration,
        uint16 _feeRatioMinerValidor,
        uint256 _daoTokenReward,
        DAOTokenPercentage memory _daoTokenPercentage
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

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

    function setWEAIAddress(address _wEAI) external onlyOwner {
        if (_wEAI == address(0)) revert InvalidAddress();
        wEAI = _wEAI;
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

        _assignMiners(inferenceId, msg.sender);

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

    function _assignMiners(uint256 _inferenceId, address _model) internal {
        uint40 expiredAt = uint40(block.number + submitDuration);
        inferences[_inferenceId].submitTimeout = expiredAt;
        inferences[_inferenceId].status = InferenceStatus.Solving;

        address[] memory miners = IStakingHub(stakingHub)
            .getMinerAddressesOfModel(_model); // TODO: kelvin change, move random to stakingHub
        if (miners.length < minerRequirement) revert NotEnoughMiners();
        uint8 index = uint8(randomizer.randomUint256() % miners.length);
        address miner = miners[index];
        inferences[_inferenceId].processedMiner = miner;
        inferencesByMiner[miner].insert(_inferenceId);

        emit NewAssignment(_inferenceId, _inferenceId, miner, expiredAt);
    }

    function _validatateSolution(bytes calldata _data) internal pure virtual {
        if (_data.length == 0) revert InvalidData();
    }

    function submitSolution(
        uint256 _inferId,
        bytes calldata _data
    ) external virtual whenNotPaused {
        IStakingHub(stakingHub).updateEpoch();
        _validatateSolution(_data);

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!IStakingHub(stakingHub).isMinerAddress(msg.sender))
            revert InvalidMiner();

        IStakingHub(stakingHub).validateModelOfMiner(msg.sender);

        // Check the msg sender is the assigned miner
        if (msg.sender != inferences[_inferId].processedMiner)
            revert Unauthorized();
        if (inferences[_inferId].output.length != 0) revert AlreadySubmitted();

        Inference memory clonedInference = inferences[_inferId];

        if (clonedInference.status != InferenceStatus.Solving) {
            revert InvalidInferenceStatus();
        }

        if (uint40(block.number) > clonedInference.submitTimeout)
            revert SubmitTimeout();

        Inference storage inference = inferences[_inferId];

        inference.output = _data; //Record the solution
        inference.status = InferenceStatus.Commit;

        emit InferenceStatusUpdate(_inferId, InferenceStatus.Commit);
        emit SolutionSubmission(msg.sender, _inferId);
    }

    function getInferenceInfo(
        uint256 _inferenceId
    ) external view returns (Inference memory) {
        return inferences[_inferenceId];
    }

    function getMinFeeToUse(
        address _modelAddress
    ) external view returns (uint256) {
        return IStakingHub(stakingHub).getMinFeeToUse(_modelAddress);
    }

    function getTreasuryAddress() external view returns (address) {
        return treasury;
    }

    function setSubmitDuration(uint40 _submitDuration) external onlyOwner {
        submitDuration = _submitDuration;
    }

    function getSubmitDuration() external view returns (uint40) {
        return submitDuration;
    }

    function getMinerRequirement() external view returns (uint8) {
        return minerRequirement;
    }

    function setStakingHubAddress(address _stakingHub) external onlyOwner {
        if (_stakingHub == address(0)) revert InvalidAddress();
        stakingHub = _stakingHub;
    }

    function setDAOTokenAddress(address _daoToken) external onlyOwner {
        if (_daoToken == address(0)) revert InvalidAddress();
        daoToken = _daoToken;
    }
}

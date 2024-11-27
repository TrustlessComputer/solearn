// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Random} from "../lib/Random.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";
import {PromptSchedulerStorage, IWorkerHub, Set} from "../storages/PromptSchedulerStorage.sol";
import {IDAOToken} from "../tokens/IDAOToken.sol";
import {IStakingHub} from "../interfaces/IStakingHub.sol";

contract PromptSchedulerNonUpgradable is
    PromptSchedulerStorage,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using Random for Random.Randomizer;
    using Set for Set.Uint256Set;
    using Set for Set.Bytes32Set;
    using Set for Set.AddressSet;

    // Define more storage here
    // START DEFINE

    struct BatchInfo {
        uint[] inferIds;
        Set.AddressSet validators;
    }
    mapping(uint => BatchInfo) internal batchInfos;
    uint public lastBatch;
    uint public lastInferIdInBatch;
    uint public lastBatchTimestamp;
    // uint public maxRequestPerBatch;
    uint public batchTime;


    // END 

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

    // assgin validators to batch
    function assignValidators() external {
        //
        address[] memory miners = IStakingHub(stakingHub).getMinerAddresses();

        // loop thru infers and assign validator
        
    }

    // validators commmit  


    // validators reveal
    // if enough vote then slash validators

    // submit proof to slash miner

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
}

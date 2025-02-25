// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Random} from "../lib/Random.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";
import {PromptSchedulerStorage, IWorkerHub, Set} from "./storages/PromptSchedulerStorage.sol";
import {IDAOToken} from "../tokens/IDAOToken.sol";
import {IStakingHub} from "./interfaces/IStakingHub.sol";

contract RealWorldPromptScheduler is
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

    function prompt(
        bytes calldata _input,
        address _creator,
        bool _flag
    ) external payable whenNotPaused returns (uint256) {
        return _prompt(_input, _creator, 0, _flag);
    }

    function prompt(
        bytes calldata _input,
        address _creator
    ) external payable whenNotPaused returns (uint256) {
        return _prompt(_input, _creator, 0, false);
    }

    function _prompt(
        bytes calldata _input,
        address _creator,
        uint256 _scoringFee,
        bool _flag
    ) internal virtual returns (uint256) {
        IStakingHub.Gateway memory gateway = IStakingHub(stakingHub).getGatewayInfo(
            msg.sender
        );
        if (gateway.tier == 0) revert Unauthorized();

        uint256 promptId = ++promptNumber;
        PromptData storage promptData = prompts[promptId];

        uint256 value = msg.value - _scoringFee;
        uint256 feeL2 = (value * feeL2Percentage) / PERCENTAGE_DENOMINATOR;
        uint256 feeTreasury = (value * feeTreasuryPercentage) /
            PERCENTAGE_DENOMINATOR;

        promptData.input = _input;
        promptData.feeL2 = feeL2;
        promptData.feeTreasury = feeTreasury;
        promptData.value = value - feeL2 - feeTreasury;
        promptData.creator = _creator;
        promptData.referrer = referrerOf[_creator];
        promptData.gatewayAddress = msg.sender;

        _assignMiners(promptId, msg.sender);

        emit NewPrompt(promptId, msg.sender, _creator, value, 0);
        emit RawSubmitted(
            promptId,
            msg.sender,
            _creator,
            value,
            0,
            _input,
            _flag
        );

        return promptId;
    }

    function _assignMiners(uint256 _promptId, address _gateway) internal {
        uint40 expiredAt = uint40(block.number + submitDuration);
        prompts[_promptId].submitTimeout = expiredAt;
        prompts[_promptId].status = PromptStatus.Solving;

        address[] memory miners = IStakingHub(stakingHub)
            .getMinerAddressesOfGateway(_gateway); // TODO: kelvin change, move random to stakingHub
        if (miners.length < minerRequirement) revert NotEnoughMiners();
        uint8 index = uint8(randomizer.randomUint256() % miners.length);
        address miner = miners[index];
        prompts[_promptId].processedMiner = miner;
        promptsByMiner[miner].insert(_promptId);

        emit NewAssignment(_promptId, _promptId, miner, expiredAt);
    }

    function _validatateSolution(bytes calldata _data) internal pure virtual {
        if (_data.length == 0) revert InvalidData();
    }

    function submitSolution(
        uint256 _promptId,
        bytes calldata _data
    ) external virtual whenNotPaused {
        IStakingHub(stakingHub).updateEpoch();
        _validatateSolution(_data);

        // Check whether miner is available (the miner had previously joined). The inactive miner is not allowed to submit solution.
        if (!IStakingHub(stakingHub).isMinerAddress(msg.sender))
            revert InvalidMiner();

        IStakingHub(stakingHub).validateGatewayOfMiner(msg.sender);

        // Check the msg sender is the assigned miner
        if (msg.sender != prompts[_promptId].processedMiner)
            revert Unauthorized();
        if (prompts[_promptId].output.length != 0) revert AlreadySubmitted();

        PromptData memory clonedPrompt = prompts[_promptId];

        if (clonedPrompt.status != PromptStatus.Solving) {
            revert InvalidPromptStatus();
        }

        if (uint40(block.number) > clonedPrompt.submitTimeout)
            revert SubmitTimeout();

        PromptData storage promptData = prompts[_promptId];

        promptData.output = _data; //Record the solution
        promptData.status = PromptStatus.Commit;

        emit PromptStatusUpdate(_promptId, PromptStatus.Commit);
        emit SolutionSubmission(msg.sender, _promptId);
    }

    function getPromptInfo(
        uint256 _promptId
    ) external view returns (PromptData memory) {
        return prompts[_promptId];
    }

    function getMinFeeToUse(
        address _gatewayAddress
    ) external view returns (uint256) {
        return IStakingHub(stakingHub).getMinFeeToUse(_gatewayAddress);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
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

    enum BatchStatus {
        Empty,
        Commit,
        Reveal,
        Completing,
        Completed,
        Expired
    }

    // error
    error Assigned();
    error NotEnoughMiner();
    error EmptyInferRequest();
    error InvalidBatchId();

    struct ValidateInfo {
        bytes32 commit;
        bytes32 reveal;
    }

    struct BatchInfo {
        uint40 timeout;
        uint16 countCommit;
        uint16 countReveal;
        BatchStatus status;
        bytes32 mostVotedRootHash;
        AccumulatedFee accFee;
        uint256[] inferIds;
        Set.AddressSet validators;
        mapping(address => ValidateInfo) commits;
        mapping(bytes32 => uint) rootHashCount;
    }

    struct AccumulatedFee {
        uint256 validatorFee;
        uint256 l2OwnerFee;
        uint256 treasuryFee;
    }

    // model => batch id => batch info
    mapping(address => mapping(uint => BatchInfo)) internal batchInfos;
    // infer id => processed miner slashed
    mapping(uint256 => bool) isSlashed;
    uint256 public lastBatchTimestamp;
    uint256 public batchPeriod;

    uint40 public commitTimeout;
    uint40 public revealTimeout;

    event ValidatorsAssigned(uint batchId, address model, address[] validators);
    event AppendToBatch(uint batchId, address model, uint inferId);
    event SubmitCommitment(
        uint batchId,
        address model,
        address validator,
        bytes32 commitment
    );
    event SubmitReveal(
        uint batchId,
        address model,
        address validator,
        bytes32 reveal
    );
    event StatusUpdate(uint batchId, address model, BatchStatus status);
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
        DAOTokenPercentage memory _daoTokenPercentage,
        uint40 _batchPeriod
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

        lastBatchTimestamp = block.timestamp;

        require(_batchPeriod != 0, "ibp");
        batchPeriod = _batchPeriod;
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

        // append to batch
        uint batchId = (block.timestamp - lastBatchTimestamp) / batchPeriod;
        batchInfos[msg.sender][batchId].inferIds.push(_inferenceId);

        emit AppendToBatch(batchId, _model, _inferenceId);
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

        // transfer fee to miner
        uint256 minerFee = (inference.value * feeRatioMinerValidator) /
            PERCENTAGE_DENOMINATOR;
        TransferHelper.safeTransferNative(msg.sender, minerFee);

        // calculate accumulated fee
        uint256 currentBatchId = (block.timestamp - lastBatchTimestamp) /
            batchPeriod;
        address model = inference.modelAddress;
        if (_inferId < batchInfos[model][currentBatchId].inferIds[0]) {
            currentBatchId--;
        }

        AccumulatedFee storage accFee = batchInfos[model][currentBatchId]
            .accFee;
        accFee.validatorFee += inference.value - minerFee;
        accFee.l2OwnerFee += inference.feeL2;
        accFee.treasuryFee += inference.feeTreasury;
    }

    // assign validators to batch
    function assignValidators(uint _batchId, address _model) external {
        address[] memory miners = IStakingHub(stakingHub)
            .getMinerAddressesOfModel(_model); // TODO: kelvin change, move random to stakingHub

        BatchInfo storage batchInfo = batchInfos[_model][_batchId];

        if (batchInfo.validators.size() != 0) {
            revert Assigned();
        }

        if (miners.length < minerRequirement) {
            revert NotEnoughMiner();
        }

        if (batchInfo.inferIds.length == 0) {
            revert EmptyInferRequest();
        }

        // check timestamp
        if (lastBatchTimestamp + _batchId * batchPeriod > block.timestamp) {
            revert InvalidBatchId();
        }

        uint8 index;
        for (uint i = 0; i < minerRequirement; ) {
            index = uint8(randomizer.randomUint256() % miners.length);
            if (batchInfo.validators.hasValue(miners[index])) {
                continue;
            } else {
                batchInfo.validators.insert(miners[index]);
                i++;
            }
        }
        batchInfo.status = BatchStatus.Commit;
        batchInfo.timeout = uint40(block.timestamp) + commitTimeout;

        emit ValidatorsAssigned(_batchId, _model, miners);
    }

    // validators commit
    function submitBatchCommitment(
        address _model,
        uint _batchId,
        bytes32 _commitment
    ) external {
        if (_commitment == 0) {
            revert("invalid value");
        }

        BatchInfo storage batchInfo = batchInfos[_model][_batchId];

        if (!batchInfo.validators.hasValue(msg.sender)) {
            revert("not validator");
        }

        if (batchInfo.status != BatchStatus.Commit) {
            revert("invalid state");
        }

        if (batchInfo.commits[msg.sender].commit != bytes32(0)) {
            revert("committed");
        }

        if (block.timestamp > batchInfo.timeout) {
            revert("expired");
        }

        // handle submission
        batchInfo.commits[msg.sender].commit = _commitment;
        batchInfo.countCommit++;

        emit SubmitCommitment(_batchId, _model, msg.sender, _commitment);

        if (batchInfo.countCommit == batchInfo.validators.size()) {
            batchInfo.status = BatchStatus.Reveal;
            batchInfo.timeout = uint40(block.timestamp) + revealTimeout;

            emit StatusUpdate(_batchId, _model, batchInfo.status);
        }
    }

    // validators reveal
    // if enough vote then slash validators
    function reveal(
        address _model,
        uint _batchId,
        address _validator,
        bytes32 _rootHash
    ) external {
        if (_rootHash == 0) {
            revert("invalid value");
        }

        //
        BatchInfo storage batchInfo = batchInfos[_model][_batchId];

        if (batchInfo.commits[_validator].commit == bytes32(0)) {
            revert("nothing to reveal");
        }

        if (batchInfo.status != BatchStatus.Reveal) {
            revert("invalid state");
        }

        if (batchInfo.commits[_validator].reveal != bytes32(0)) {
            revert("committed");
        }

        if (block.timestamp > batchInfo.timeout) {
            revert("expired");
        }

        bytes memory tempData = abi.encodePacked(_validator, _rootHash);
        if (keccak256(tempData) != batchInfo.commits[_validator].commit) {
            revert("not match commitment");
        }

        // handle submission
        batchInfo.commits[_validator].reveal = _rootHash;
        batchInfo.countReveal++;
        batchInfo.rootHashCount[_rootHash]++;

        // final the most voted root hash
        if (
            batchInfo.rootHashCount[_rootHash] >=
            _getThresholdValue(batchInfo.validators.size()) &&
            batchInfo.mostVotedRootHash == 0
        ) {
            batchInfo.mostVotedRootHash = _rootHash;
        }

        emit SubmitReveal(_batchId, _model, _validator, _rootHash);

        if (batchInfo.countReveal == batchInfo.validators.size()) {
            batchInfo.status = BatchStatus.Completing;

            resolveBatch(_model, _batchId);
        }
    }

    function _getThresholdValue(uint x) internal pure returns (uint) {
        return (x * 2) / 3 + (x % 3 == 0 ? 0 : 1);
    }

    // resovle batch
    function resolveBatch(address _model, uint _batchId) public nonReentrant {
        BatchInfo storage batchInfo = batchInfos[_model][_batchId];
        uint validatorSize = batchInfo.validators.size();

        // handle commit timeout
        if (
            batchInfo.status == BatchStatus.Commit &&
            batchInfo.timeout < block.timestamp
        ) {
            // move on if has majority commited
            if (batchInfo.countCommit >= _getThresholdValue(validatorSize)) {
                batchInfo.status = BatchStatus.Reveal;
                batchInfo.timeout = uint40(block.timestamp) + revealTimeout;

                emit StatusUpdate(_batchId, _model, batchInfo.status);
            } else {
                // ! We need to slash validators who did not commit in time with the param isFined set to true
                // slash validator did not commit in time
                for (uint i = 0; i < validatorSize; i++) {
                    address validator = batchInfo.validators.values[i];
                    if (batchInfo.commits[validator].commit == bytes32(0))
                        IStakingHub(stakingHub).slashMiner(validator, false);
                }

                batchInfo.status = BatchStatus.Expired;

                emit StatusUpdate(_batchId, _model, batchInfo.status);
                return;
            }
        }

        // handle reveal timeout
        if (
            batchInfo.status == BatchStatus.Reveal &&
            batchInfo.timeout < block.timestamp
        ) {
            if (batchInfo.countReveal >= _getThresholdValue(validatorSize)) {
                batchInfo.status = BatchStatus.Completing;

                emit StatusUpdate(_batchId, _model, batchInfo.status);

                // call back to resolve batch infer
                this.resolveBatch(_model, _batchId); // ! Can we remove this line?
            } else {
                // slash validator did not reveal in time
                for (uint i = 0; i < validatorSize; i++) {
                    address validator = batchInfo.validators.values[i];
                    // ! If a validator did not commit, then he can not reveal. So we only need to slash un-reveal validators.
                    // ! The validators who did not commit will be slashed with the isFined flag set to true because they make a batch to expired.
                    if (
                        batchInfo.commits[validator].commit == bytes32(0) ||
                        batchInfo.commits[validator].reveal == bytes32(0)
                    ) IStakingHub(stakingHub).slashMiner(validator, false);
                }

                batchInfo.status = BatchStatus.Expired;

                emit StatusUpdate(_batchId, _model, batchInfo.status);
            }
        }

        // handle completed batch
        if (batchInfo.status == BatchStatus.Completing) {
            //
            bytes32 mostVotedRootHash = batchInfo.mostVotedRootHash;
            if (mostVotedRootHash != 0) {
                uint256 counter = batchInfos[_model][_batchId].rootHashCount[
                    mostVotedRootHash
                ];
                uint256 validatorFee = batchInfo.accFee.validatorFee / counter;
                //
                for (uint i = 0; i < validatorSize; i++) {
                    address validator = batchInfo.validators.values[i];
                    if (
                        batchInfo.commits[validator].reveal != mostVotedRootHash
                    ) {
                        IStakingHub(stakingHub).slashMiner(validator, true);
                    } else {
                        // distribute fee
                        TransferHelper.safeTransferNative(
                            validator,
                            validatorFee
                        );
                    }
                }
            }

            // If the batch is completed but validators cannot reach consensus, we transfer the validator fee to the treasury
            uint256 treasuryFee = batchInfo.accFee.treasuryFee;

            if (mostVotedRootHash == 0) {
                treasuryFee += batchInfo.accFee.validatorFee;
            }

            TransferHelper.safeTransferNative(treasury, treasuryFee);
            TransferHelper.safeTransferNative(
                l2Owner,
                batchInfo.accFee.l2OwnerFee
            );

            batchInfo.status = BatchStatus.Completed;

            emit StatusUpdate(_batchId, _model, batchInfo.status);
        }
    }

    function checkInferIdExistsInBatch(
        uint256[] memory inferIds,
        uint256 _inferId
    ) internal pure returns (bool) {
        uint256 left = 0;
        uint256 right = inferIds.length - 1;
        while (left <= right) {
            uint256 mid = (left + right) / 2;
            if (inferIds[mid] == _inferId) {
                return true;
            } else if (inferIds[mid] < _inferId) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        return false;
    }

    // submit proof to slash miner
    // node leaf = hash(inferId | hash(output))
    function slashMiner(
        address _model,
        uint _batchId,
        uint _inferId,
        bytes32[] memory proof,
        bytes32 _leafData
    ) external {
        BatchInfo storage batchInfo = batchInfos[_model][_batchId];

        if (isSlashed[_inferId]) {
            revert("slashed");
        }

        if (batchInfo.mostVotedRootHash == 0) {
            revert("voting not finalized");
        }

        if (!checkInferIdExistsInBatch(batchInfo.inferIds, _inferId)) {
            revert("wrong batch");
        }

        bytes32 nodeLeaf = keccak256(abi.encodePacked(_inferId, _leafData));

        if (
            MerkleProof.verify(proof, batchInfo.mostVotedRootHash, nodeLeaf) &&
            keccak256(inferences[_inferId].output) != _leafData
        ) {
            IStakingHub(stakingHub).slashMiner(
                inferences[_inferId].processedMiner,
                true
            );
            isSlashed[_inferId] = true;
        } else {
            revert("false accusation");
        }
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
}

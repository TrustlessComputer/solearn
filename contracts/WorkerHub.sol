// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import {IHybridModel} from "./interfaces/IHybridModel.sol";
import {IWorkerHub} from "./interfaces/IWorkerHub.sol";

abstract contract WorkerHubStorage is IWorkerHub {
    mapping(address => bool) public isModel;
    mapping(address => Worker) internal workers;
    mapping(uint256 => Inference) internal inferences;
    mapping(uint256 => UnstakeRequest) internal unstakeRequests;

    uint256 public inferenceNumber;
    uint256 public unstakeRequestNumber;
    uint256 public minimumStake;

    uint8 public feePercentage;
    uint8 public royaltyPercentage;
    uint40 public stakeLockingDuration;

    address public treasury;
    address public collection;

    uint256[50] private __gap;
}

contract WorkerHub is
WorkerHubStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    function initialize(
        address _treasury,
        address _collection,
        uint8 _feePercentage,
        uint8 _royaltyPercentage,
        uint256 _minimumStake,
        uint40 _stakeLockingDuration
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        if (_feePercentage + _royaltyPercentage > 100) revert ConflictedPercentage();

        treasury = _treasury;
        collection = _collection;
        feePercentage = _feePercentage;
        royaltyPercentage = _royaltyPercentage;
        minimumStake = _minimumStake;
        stakeLockingDuration = _stakeLockingDuration;
    }

    function version() external pure returns (string memory) {
        return "v0.0.1";
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdate(_treasury);
    }

    function updateCollection(address _collection) external onlyOwner {
        collection = _collection;
        emit CollectionUpdate(_collection);
    }

    function updateFeePercentage(uint8 _feePercentage) external onlyOwner {
        feePercentage = _feePercentage;
        emit FeePercentageUpdate(_feePercentage);
    }

    function updateRoyaltyPercentage(uint8 _royaltyPercentage) external onlyOwner {
        royaltyPercentage = _royaltyPercentage;
        emit RoyaltyPercentageUpdate(_royaltyPercentage);
    }

    function updateMinimumStake(uint256 _minimumStake) external onlyOwner {
        minimumStake = _minimumStake;
        emit MinimumStakeUpdate(_minimumStake);
    }

    function updateStakeLockingDuration(uint40 _stakeLockingDuration) external onlyOwner {
        stakeLockingDuration = _stakeLockingDuration;
        emit StakeLockingDurationUpdate(_stakeLockingDuration);
    }

    function registerModel(address _model) external onlyOwner {
        if (isModel[_model]) revert AlreadyRegistered();

        isModel[_model] = true;

        emit ModelRegistration(_model);
    }

    function unregisterModel(address _model) external onlyOwner {
        if (!isModel[_model]) revert NotRegistered();

        isModel[_model] = false;

        emit ModelUnregistration(_model);
    }

    function authorizeWorker(address _worker) external onlyOwner {
        workers[_worker].isAuthorized = true;

        emit WorkerAuthorization(_worker);
    }

    function unauthorizeWorker(address _worker) external onlyOwner {
        workers[_worker].isAuthorized = false;

        emit WorkerUnauthorization(_worker);
    }

    function getInference(uint256 _inferenceId) external view returns (Inference memory) {
        if (_inferenceId == 0 || _inferenceId > inferenceNumber) revert InvalidInferenceId();
        return inferences[_inferenceId];
    }

    function getInferences() external view returns (Inference[] memory) {
        Inference[] memory result = new Inference[](inferenceNumber);
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            result[i] = inferences[i];
        }
        return result;
    }

    function getUnresolvedInferences() external view returns (UnresolvedInference[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (!inferences[i].isResolved) {
                counter++;
            }
        }
        UnresolvedInference[] memory result = new UnresolvedInference[](counter);
        counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (!inferences[i].isResolved) {
                Inference memory inference = inferences[i];
                result[counter++] = UnresolvedInference(
                    i,
                    inference.value,
                    inference.data,
                    inference.model,
                    inference.creator
                );
            }
        }

        return result;
    }

    function getIndividualInferences(address _account) external view returns (Inference[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (inferences[i].creator == _account) {
                counter++;
            }
        }

        Inference[] memory result = new Inference[](counter);
        counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (inferences[i].creator == _account) {
                result[counter++] = inferences[i];
            }
        }

        return result;
    }

    function getIndividualUnresolvedInferences(address _account) external view returns (UnresolvedInference[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (!inferences[i].isResolved && inferences[i].creator == _account) {
                counter++;
            }
        }

        UnresolvedInference[] memory result = new UnresolvedInference[](counter);
        counter = 0;
            for (uint256 i = 1; i <= inferenceNumber; ++i) {
                if (!inferences[i].isResolved && inferences[i].creator == _account) {
                    Inference memory inference = inferences[i];
                    result[counter++] = UnresolvedInference(
                        i,
                        inference.value,
                        inference.data,
                        inference.model,
                        inference.creator
                    );
                }
            }

        return result;
    }

    function getModelInferences(address _model) external view returns (Inference[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (inferences[i].model == _model) {
                counter++;
            }
        }

        Inference[] memory result = new Inference[](counter);
        counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (inferences[i].model == _model) {
                result[counter++] = inferences[i];
            }
        }

        return result;
    }

    function getModelUnresolvedInferences(address _model) external view returns (UnresolvedInference[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (!inferences[i].isResolved && inferences[i].model == _model) {
                counter++;
            }
        }

        UnresolvedInference[] memory result = new UnresolvedInference[](counter);
        counter = 0;
        for (uint256 i = 1; i <= inferenceNumber; ++i) {
            if (!inferences[i].isResolved && inferences[i].model == _model) {
                Inference memory inference = inferences[i];
                result[counter++] = UnresolvedInference(
                    i,
                    inference.value,
                    inference.data,
                    inference.model,
                    inference.creator
                );
            }
        }

        return result;
    }

    function getWorker(address _worker) external view returns (Worker memory) {
        return workers[_worker];
    }

    function getUnstakeRequest(uint256 _requestId) external view returns (UnstakeRequest memory) {
        return unstakeRequests[_requestId];
    }

    function getIndividualUnstakeRequests(address _account) external view returns (UnstakeRequest[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= unstakeRequestNumber; ++i) {
            if (unstakeRequests[i].worker == _account) {
                counter++;
            }
        }

        UnstakeRequest[] memory result = new UnstakeRequest[](counter);
        counter = 0;
        for (uint256 i = 1; i <= unstakeRequestNumber; ++i) {
            if (unstakeRequests[i].worker == _account) {
                result[counter++] = unstakeRequests[i];
            }
        }

        return result;
    }

    function getIndividualWithdrawableUnstakeRequests(address _account) external view returns (UnstakeRequest[] memory) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= unstakeRequestNumber; ++i) {
            if (unstakeRequests[i].worker == _account
                && unstakeRequests[i].unlockedAt <= block.timestamp
                && !unstakeRequests[i].isWithdrawn) {
                counter++;
            }
        }

        UnstakeRequest[] memory result = new UnstakeRequest[](counter);
        counter = 0;
        for (uint256 i = 1; i <= unstakeRequestNumber; ++i) {
            if (unstakeRequests[i].worker == _account
                && unstakeRequests[i].unlockedAt <= block.timestamp
                && !unstakeRequests[i].isWithdrawn) {
                result[counter++] = unstakeRequests[i];
            }
        }

        return result;
    }

    function stake() external payable whenNotPaused {
        if (!workers[msg.sender].isAuthorized) revert Unauthorized();

        workers[msg.sender].stakedValue += msg.value;

        emit Stake(msg.sender, msg.value);
    }

    function requestUnstake(uint256 _value) external whenNotPaused {
        uint256 stakedValue = workers[msg.sender].stakedValue;
        if (_value > stakedValue) revert InsufficientFunds();

        unchecked {
            workers[msg.sender].stakedValue = stakedValue - _value;

            uint256 requestId = ++unstakeRequestNumber;

            unstakeRequests[unstakeRequestNumber] = UnstakeRequest(
                _value,
                msg.sender,
                uint40(block.timestamp) + stakeLockingDuration,
                false
            );

            emit NewUnstakeRequest(
                requestId,
                msg.sender,
                _value
            );
        }
    }

    function unstake(uint256[] calldata _requestIds) external nonReentrant whenNotPaused {
        uint256 totalStake;

        unchecked {
            for (uint256 i = 0; i < _requestIds.length; ++i) {
                UnstakeRequest storage unstakeRequest = unstakeRequests[_requestIds[i]];
                if (unstakeRequest.worker != msg.sender) revert Unauthorized();
                if (unstakeRequest.unlockedAt > block.timestamp) revert StakeIsNotUnlockedYet();
                if (unstakeRequest.isWithdrawn) revert RequestIsAlreadyWithdrawn();
                totalStake += unstakeRequest.value;
                unstakeRequest.isWithdrawn = true;
            }
        }

        (bool success, ) = msg.sender.call{value: totalStake}("");
        if (!success) revert FailedTransfer();

        emit Unstake(msg.sender, _requestIds);
    }

    function infer(bytes calldata _data, address _creator) external payable whenNotPaused returns (uint256) {
        if (!isModel[msg.sender]) revert Unauthorized();

        uint256 inferenceId = ++inferenceNumber;
        inferences[inferenceId] = Inference(
            msg.value,
            _data,
            '',
            false,
            msg.sender,
            _creator,
            address(0)
        );

        emit NewInference(inferenceId);

        return inferenceId;
    }

    function submitResult(uint256 _inferenceId, bytes calldata _result) external nonReentrant whenNotPaused {
        if (_inferenceId == 0 || _inferenceId > inferenceNumber) revert InvalidInferenceId();
        if (feePercentage + royaltyPercentage > 100) revert ConflictedPercentage();

        Inference storage inference = inferences[_inferenceId];
        if (inference.isResolved) revert InferenceIsAlreadyResolved();

        Worker memory worker = workers[msg.sender];
        if (!worker.isAuthorized) revert Unauthorized();
        if (worker.stakedValue < minimumStake) revert NotEnoughStake();

        inference.result = _result;
        inference.isResolved = true;
        inference.worker = msg.sender;

        unchecked {
            uint256 value = inference.value;
            uint256 fee = value * feePercentage / 100;
            uint256 reward = value - fee;
            bool success;
            (success, ) = treasury.call{value: fee}("");
            if (!success) revert FailedTransfer();

            uint256 modelIdentifier = IHybridModel(inference.model).identifier();
            if (modelIdentifier != 0) {
                address modelOwner = IERC721Upgradeable(collection).ownerOf(modelIdentifier);
                uint256 royalty = value * royaltyPercentage / 100;
                reward -= royalty;
                (success, ) = modelOwner.call{value: royalty}("");
                if (!success) revert FailedTransfer();
            }

            (success, ) = msg.sender.call{value: reward}("");
            if (!success) revert FailedTransfer();

            emit ResultSubmission(_inferenceId, msg.sender);
        }
    }
}

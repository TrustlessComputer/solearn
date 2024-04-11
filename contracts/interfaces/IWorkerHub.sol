// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWorkerHub {
    struct Inference {
        uint256 value;
        uint256 modelId;
        bytes data;
        bytes result;
        bool isResolved;
        address model;
        address creator;
        address worker;
    }

    struct Worker {
        uint256 stakedValue;
        bool isAuthorized;
    }

    struct UnresolvedInference {
        uint256 requestId;
        uint256 value;
        bytes data;
        address model;
        address creator;
    }

    struct UnstakeRequest {
        uint256 value;
        address worker;
        uint40 unlockedAt;
        bool isWithdrawn;
    }

    event CollectionUpdate(address newAddress);
    event TreasuryUpdate(address newAddress);

    event FeePercentageUpdate(uint8 newValue);
    event MinimumStakeUpdate(uint256 newValue);
    event RoyaltyPercentageUpdate(uint8 newValue);
    event StakeLockingDurationUpdate(uint40 newValue);

    event ModelRegistration(address model);
    event ModelUnregistration(address model);

    event WorkerAuthorization(address worker);
    event WorkerUnauthorization(address worker);

    event NewUnstakeRequest(uint256 indexed requestId, address indexed worker, uint256 value);
    event Stake(address indexed worker, uint256 value);
    event Unstake(address indexed worker, uint256[] requestIds);

    event NewInference(uint256 indexed inferenceId, address indexed creator);
    event ResultSubmission(uint256 indexed inferenceId, address indexed worker);

    error AlreadyRegistered();
    error ConflictedPercentage();
    error FailedTransfer();
    error InferenceIsAlreadyResolved();
    error InsufficientFunds();
    error InvalidInferenceId();
    error NotEnoughStake();
    error NotRegistered();
    error StakeIsNotUnlockedYet();
    error RequestIsAlreadyWithdrawn();
    error Unauthorized();

    function version() external pure returns (string memory);

    function collection() external view returns (address collectionAddress);
    function feePercentage() external view returns (uint8 feePercentage);
    function inferenceNumber() external view returns (uint256 interferenceNumber);
    function minimumStake() external view returns (uint256 minimumStake);
    function royaltyPercentage() external view returns (uint8 royaltyPercentage);
    function stakeLockingDuration() external view returns (uint40 stakeLockingDuration);
    function unstakeRequestNumber() external view returns (uint256 unstakeRequestNumber);
    function treasury() external view returns (address treasuryAddress);

    function getIndividualInferences(address account)
    external view returns (Inference[] memory inferences);
    function getIndividualUnresolvedInferences(address account)
    external view returns (UnresolvedInference[] memory inferences);
    function getIndividualUnstakeRequests(address account)
    external view returns (UnstakeRequest[] memory requests);
    function getIndividualWithdrawableUnstakeRequests(address _account)
    external view returns (UnstakeRequest[] memory requests);
    function getInference(uint256 inferenceId)
    external view returns (Inference memory inference);
    function getInferences()
    external view returns (Inference[] memory inferences);
    function getModelInferences(address model)
    external view returns (Inference[] memory inferences);
    function getModelUnresolvedInferences(address model)
    external view returns (UnresolvedInference[] memory inferences);
    function getUnresolvedInferences()
    external view returns (UnresolvedInference[] memory inferences);
    function getUnstakeRequest(uint256 requestId)
    external view returns (UnstakeRequest memory);
    function getWorker(address worker)
    external view returns (Worker memory workerData);

    function stake() external payable;
    function requestUnstake(uint256 value) external;
    function unstake(uint256[] calldata requestIds) external;

    function infer(bytes calldata data, uint256 identifier, address creator) external payable returns (uint256);
    function submitResult(uint256 inferenceId, bytes calldata result) external;
}

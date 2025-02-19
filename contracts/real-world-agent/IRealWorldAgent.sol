// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRealWorldAgent {
    // ENUM DEFINES
    enum RequestStatus {
        EMPTY,
        PENDING,
        EXECUTED,
        FAILED
    }

    // STRUCT DEFINES
    struct Request {
        bytes32 uuid;
        address creator;
        uint32 timeout;
        RequestStatus status;
        bytes data;
        bytes result;
    }

    // EVENT DEFINES
    event ExecutionRequested(
        uint256 indexed actId,
        bytes32 indexed uuid,
        address indexed creator,
        bytes data
    );
    event SolutionSubmitted(
        uint256 indexed actId,
        address indexed processor,
        bytes result
    );
    event WorkerUpdated(address indexed oldWorker, address indexed newWorker);

    // ERROR DEFINES
    error DuplicateUuid();
    error InvalidRequestStatus();
    error Timeout();
    error Unauthorized();
    error InvalidUuid();
    error ZeroAddress();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidSignature();
    error InvalidExternalDataLength();

    function act(
        bytes32 uuid,
        bytes memory executeData
    ) external returns (uint256);

    /**
     * @notice Retrieves the minimum fee required to use agent.
     * @return The minimum fee required to use the agent.
     */
    function getMinFeeToUse() external view returns (uint256);

    /**
     * @notice Retrieves the result of an execution by its uuid.
     * @param uuid The uuid of the execution to retrieve the result for.
     * @return The result of the execution.
     */
    function getResultById(bytes32 uuid) external view returns (bytes memory);
}

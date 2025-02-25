// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IUtilityAgent {
    struct StorageInfo {
        address contractAddress;
        string filename;
    }

    event StorageInfoUpdate(uint256 indexed cfIndex, StorageInfo newInfo);
    event StorageInfoRemoved(uint256 indexed cfIndex);
    event EndpointUpdate(string key, string value);
    event SystemPromptUpdate(string newSystemPrompt);

    error InvalidData();
    error ZeroAddress();

    /**
     * @notice Updates the storage information for a given index.
     * @param cfIndex The index of the storage information to update.
     * @param storageInfo The new storage information.
     */
    function updateStorageInfo(
        uint256 cfIndex,
        StorageInfo calldata storageInfo
    ) external;

    /**
     * @notice Fetches all file codes.
     * @return filename An array of filenames.
     * @return logic An array of file contents.
     */
    function fetchAllFileCodes()
        external
        view
        returns (string[] memory filename, string[] memory logic);

    /**
     * @notice Fetches the file code from a given storage configuration.
     * @param config The storage configuration.
     * @return logic The file content.
     */
    function fetchFileCodeFromConfig(
        StorageInfo memory config
    ) external view returns (string memory logic);

    /**
     * @notice Gets the storage mode for a given storage configuration.
     * @param config The storage configuration.
     * @return The storage mode ("fs" or "ipfs").
     */
    function getStorageMode(
        StorageInfo memory config
    ) external view returns (string memory);

    /**
     * @notice Gets all storage configurations.
     * @return configs An array of storage configurations.
     */
    function getStorageInfo()
        external
        view
        returns (StorageInfo[] memory configs);

    /**
     * @notice Updates the system prompt.
     * @param _systemPrompt The new system prompt.
     */
    function updateSystemPrompt(string calldata _systemPrompt) external;

    /**
     * @notice Gets the system prompt.
     * @return The system prompt.
     */
    function getSystemPrompt() external view returns (string memory);

    /**
     * @notice Updates multiple endpoints.
     * @param keys An array of endpoint keys.
     * @param values An array of endpoint values.
     */
    function updateEndpoints(
        string[] calldata keys,
        string[] calldata values
    ) external;

    /**
     * @notice Updates a single endpoint.
     * @param key The endpoint key.
     * @param value The endpoint value.
     */
    function updateEndpoint(
        string calldata key,
        string calldata value
    ) external;

    /**
     * @notice Gets the value of an endpoint.
     * @param key The endpoint key.
     * @return value The endpoint value.
     */
    function getEndpoint(
        string calldata key
    ) external view returns (string memory value);

    /**
     * @notice Returns the number of configurations.
     * @dev This function is a view function, meaning it does not modify the state.
     * @return The number of configurations as a uint256.
     */
    function getConfigsNumber() external view returns (uint256);
}

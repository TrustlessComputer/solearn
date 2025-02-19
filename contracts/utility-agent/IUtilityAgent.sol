// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IUtilityAgent {
    struct StorageInfo {
        address contractAddress;
        string filename;
    }

    function getPromptSchedulerAddress() external view returns (address);
    function getModelAddress() external view returns (address);
    function getSystemPrompt() external view returns (string memory);

    function prompt(bytes calldata request) external returns (uint256);
    function getResultById(uint256 id) external view returns (bytes memory);

    function fetchCode() external view returns (string memory logic);
    function getStorageMode() external view returns (string memory);
    function getStorageInfo() external view returns (StorageInfo memory);
    function getFileStorageChunkInfo() external view returns (File memory file);

    function updateSystemPrompt(string memory _systemPrompt) external;
    function updateFileName(string memory filename) external;

    event PromptSchedulerHubUpdate(address promptScheduler);
    event ModelUpdate(address hybridModel);
    event SystemPromptUpdate(string systemPrompt);
    event PromptPerformed(
        address indexed caller,
        uint256 indexed inferId,
        bytes request
    );

    error InvalidAddress();
    error InvalidData();
}

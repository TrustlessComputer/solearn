// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IUtilityAgent {
    struct StorageInfo {
        address contractAddress;
        string filename;
    }

    event FileNameUpdate(string newFilename);
    event SystemPromptUpdate(string newSystemPrompt);

    error InvalidData();
    error ZeroAddress();

    function updateFileName(string memory filename) external;
    function fetchCode() external view returns (string memory logic);
    function getStorageMode() external view returns (string memory);
    function getStorageInfo() external view returns (StorageInfo memory);
    function getFileStorageChunkInfo() external view returns (File memory file);
    function updateSystemPrompt(string memory _systemPrompt) external;
    function getSystemPrompt() external view returns (string memory);
}

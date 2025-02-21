// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";
import {ICommonAgent} from "../interfaces/ICommonAgent.sol";

interface IUtilityAgent is ICommonAgent {
    struct StorageInfo {
        address contractAddress;
        string filename;
    }

    event FileNameUpdate(string newFilename);

    event ForwardPerformed(
        bytes32 indexed uuid,
        uint256 indexed inferId,
        address indexed caller,
        bytes fowardData
    );

    function updateFileName(string memory filename) external;
    function forward(
        bytes32 uuid,
        address dstAgent,
        bytes memory request
    ) external payable returns (uint256);

    function fetchCode() external view returns (string memory logic);
    function getStorageMode() external view returns (string memory);
    function getStorageInfo() external view returns (StorageInfo memory);
    function getFileStorageChunkInfo() external view returns (File memory file);
    function getRequestInfo(
        bytes32 uuid
    ) external view returns (RequestInfo memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IAgent {
    enum FileType {
        LIBRARY,
        MAIN_SCRIPT
    }

    struct CodePointer {
        address retrieveAddress;
        FileType fileType;
        string fileName;
    }

    struct Endpoint {
        string key;
        string value;
    }

    event CodePointerCreated(
        uint256 indexed version,
        uint256 indexed pIndex,
        CodePointer newPointer
    );
    event EndpointUpdated(uint256 version, Endpoint endpoint);

    error InvalidData();
    error ZeroAddress();
    error InvalidVersion();
    error InvalidPointer(address retrieveAddress, string fileName);

    function publishAgentCode(
        CodePointer[] calldata pointers,
        Endpoint[] calldata endpoints
    ) external;

    function updateEndpoints(
        uint16 version,
        Endpoint[] calldata endpoints
    ) external;

    function getEndpoints(
        uint16 version,
        string[] memory epKeys
    ) external view returns (string[] memory epValues);

    function getAgentCode(
        uint16 version
    ) external view returns (string memory code);

    function getCodeLanguage() external view returns (string memory);

    function getCurrentVersion() external view returns (uint16);
}

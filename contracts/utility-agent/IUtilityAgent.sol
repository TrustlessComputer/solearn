// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IUtilityAgent {
    enum FileType {
        NIL,
        LIBRARY,
        DEV_SCRIPT
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

    event CodePointerCreate(
        uint256 indexed version,
        uint256 indexed pIndex,
        CodePointer newPointer
    );
    event EndpointUpdate(uint256 version, Endpoint endpoint);

    error InvalidData();
    error ZeroAddress();
    error InvalidVersion();

    function addNewAgentConfigs(
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

    function fetchAllAgentLogic(
        uint16 version
    ) external view returns (string memory code);

    function getImplementationLanguage() external view returns (string memory);

    function getCurrentVersion() external view returns (uint16);
}

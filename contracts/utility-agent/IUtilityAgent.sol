// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";

interface IUtilityAgent {
    enum FileType {
        LIBRARY,
        DEV_SCRIPT
    }

    struct AgentLogicConfig {
        address fileStore;
        FileType fileType;
        string fileName;
    }

    struct Endpoint {
        string key;
        string value;
    }

    event AgentLogicConfigCreate(
        uint256 indexed version,
        uint256 indexed cfIndex,
        AgentLogicConfig newConfig
    );
    event AgentLogicConfigUpdate(
        uint256 indexed version,
        uint256 indexed cfIndex,
        AgentLogicConfig newConfig
    );
    event AgentLogicConfigRemove(
        uint256 indexed version,
        uint256 indexed cfIndex
    );
    event EndpointUpdate(uint256 indexed version, Endpoint endpoint);

    error InvalidData();
    error InvalidVersion();
    error ZeroAddress();

    function bumpVersion() external;

    function getCurrentVersion() external view returns (uint16);

    function addNewAgentConfigs(
        uint16 version,
        AgentLogicConfig[] calldata logicCfs,
        string[] calldata keys,
        string[] calldata values
    ) external;

    function updateAgentLogicConfig(
        uint16 version,
        uint256 cfIdx,
        AgentLogicConfig calldata cf
    ) external;

    function removeAgentLogicConfig(uint16 version, uint256 cfIdx) external;

    function updateEndpoints(
        uint16 version,
        string[] calldata keys,
        string[] calldata values
    ) external;

    function getEndpoints(
        uint16 version,
        string[] calldata keys
    ) external view returns (string[] memory values);

    function fetchAllAgentLogic(
        uint16 version
    ) external view checkVersion(version) returns (string memory code);

    function fetchLogicByConfig(
        AgentLogicConfig memory cf
    ) public view virtual returns (string memory logic);

    function getStorageMode(
        AgentLogicConfig memory cf
    ) public view virtual returns (string memory);
}

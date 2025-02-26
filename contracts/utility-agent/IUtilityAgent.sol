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

    event AgentLogicConfigCreate(
        uint256 indexed cfIndex,
        AgentLogicConfig newConfig
    );
    event AgentLogicConfigUpdate(
        uint256 indexed cfIndex,
        AgentLogicConfig newConfig
    );
    event AgentLogicConfigRemove(uint256 indexed cfIndex);
    event EndpointUpdate(string key, string value);

    error InvalidData();
    error ZeroAddress();

    function addNewAgentConfig(
        AgentLogicConfig[] calldata logicCfs,
        string[] calldata keys,
        string[] calldata values
    ) external;

    function updateAgentLogicConfig(
        uint256 cfIdx,
        AgentLogicConfig calldata cf
    ) external;

    function removeAgentLogicConfig(uint256 cfIdx) external;

    function updateEndpoints(
        string[] calldata keys,
        string[] calldata values
    ) external;

    function getEndpoints(
        string[] calldata keys
    ) external view returns (string[] memory values);

    function fetchAllAgentLogic()
        external
        view
        returns (string[] memory filename, string[] memory logic);

    function fetchLogicByConfig(
        AgentLogicConfig memory cf
    ) external view returns (string memory logic);

    function getStorageMode(
        AgentLogicConfig memory config
    ) external view returns (string memory);

    function getAgentLogicConfigs()
        external
        view
        returns (AgentLogicConfig[] memory configs);

    function getConfigsNumber() external view returns (uint256);
}

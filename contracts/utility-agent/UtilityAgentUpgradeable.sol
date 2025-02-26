// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

contract UtilityAgentUpgradeable is IUtilityAgent, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));

    string public builtWith = "javascript"; // e.g., "python", "java"
    mapping(string => string) private _endPoints;
    uint256 private _configsNum;
    mapping(uint256 => AgentLogicConfig) private _agentLogicConfigs;

    uint256[50] private __gap;

    function initialize(
        AgentLogicConfig[] calldata logicCfs
    ) external initializer {
        __Ownable_init();

        uint256 len = logicCfs.length;

        for (uint256 i = 0; i < len; i++) {
            _addNewAgentLogicConfig(logicCfs[i]);
        }
    }

    function addNewAgentConfig(
        AgentLogicConfig[] calldata logicCfs,
        string[] calldata keys,
        string[] calldata values
    ) external virtual onlyOwner {
        uint256 epLen = keys.length;

        if (epLen != values.length) {
            revert InvalidData();
        }

        uint256 cfLen = logicCfs.length;

        for (uint256 i = 0; i < cfLen; i++) {
            _addNewAgentLogicConfig(logicCfs[i]);
        }

        for (uint256 i = 0; i < epLen; i++) {
            _updateEndpoint(keys[i], values[i]);
        }
    }

    /**
     * @notice Adds new storage information.
     * @param storageInfo The storage information to add.
     */
    function _addNewAgentLogicConfig(
        AgentLogicConfig calldata storageInfo
    ) internal virtual {
        _agentLogicConfigs[_configsNum] = storageInfo;
        emit AgentLogicConfigCreate(_configsNum, storageInfo);
        _configsNum++;
    }

    function updateAgentLogicConfig(
        uint256 cfIdx,
        AgentLogicConfig calldata cf
    ) external onlyOwner {
        if (cfIdx >= _configsNum) {
            revert InvalidData();
        }
        _updateAgentLogicConfig(cfIdx, cf);
    }

    function _updateAgentLogicConfig(
        uint256 cfIdx,
        AgentLogicConfig calldata cf
    ) internal virtual {
        _agentLogicConfigs[cfIdx] = cf;
        emit AgentLogicConfigUpdate(cfIdx, cf);
    }

    function removeAgentLogicConfig(uint256 cfIdx) external onlyOwner {
        if (cfIdx >= _configsNum) {
            revert InvalidData();
        }

        uint256 lastIdx = _configsNum - 1;
        if (cfIdx < lastIdx) {
            _agentLogicConfigs[cfIdx] = _agentLogicConfigs[lastIdx];
        }

        delete _agentLogicConfigs[lastIdx];
        _configsNum--;
        emit AgentLogicConfigRemove(cfIdx);
    }

    function updateEndpoints(
        string[] calldata keys,
        string[] calldata values
    ) external onlyOwner {
        uint256 len = keys.length;

        if (len != values.length) {
            revert InvalidData();
        }

        for (uint256 i = 0; i < len; i++) {
            _updateEndpoint(keys[i], values[i]);
        }
    }

    function _updateEndpoint(
        string calldata key,
        string calldata value
    ) internal virtual {
        _endPoints[key] = value;
        emit EndpointUpdate(key, value);
    }

    function getEndpoints(
        string[] calldata keys
    ) external view returns (string[] memory values) {
        uint256 len = keys.length;
        values = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            values[i] = _endPoints[keys[i]];
        }
    }

    function fetchCode() external view returns (string memory code) {
        string memory libsCode = "";
        string memory devScripts = "";
        uint256 len = _configsNum;
        // logic = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            AgentLogicConfig memory cf = _agentLogicConfigs[i];
            string memory trunk = fetchLogicByConfig(cf);

            if (cf.fileType == FileType.LIBRARY) {
                libsCode = string(abi.encodePacked(libsCode, trunk));
            } else if (cf.fileType == FileType.DEV_SCRIPT) {
                devScripts = string(abi.encodePacked(devScripts, trunk));
            }
        }

        return _buildScript(libsCode, devScripts);
    }

    function _buildScript(
        string memory libsCode,
        string memory devScripts
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<script sandbox="allow-scripts" type="text/javascript" name="DECOMPRESS_LIB" src="data:@file/javascript;base64,',
                    libsCode,
                    '"></script>',
                    '<script name="dev">getGzipFile(dataURItoBlob("',
                    devScripts,
                    '"));</script>'
                )
            );
    }

    function fetchAllAgentLogic()
        external
        view
        virtual
        returns (string[] memory filename, string[] memory logic)
    {
        uint256 len = _configsNum;
        filename = new string[](len);
        logic = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            filename[i] = _agentLogicConfigs[i].fileName;
            logic[i] = fetchLogicByConfig(_agentLogicConfigs[i]);
        }
    }

    function fetchLogicByConfig(
        AgentLogicConfig memory cf
    ) public view virtual returns (string memory logic) {
        if (keccak256(bytes(getStorageMode(cf))) == _IPFS_SIG) {
            logic = cf.fileName; // return the IPFS hash
        } else {
            logic = IFileStore(cf.fileStore).getFile(cf.fileName).read();
        }
    }

    function getStorageMode(
        AgentLogicConfig memory cf
    ) public view virtual returns (string memory) {
        if (cf.fileStore != address(0)) {
            return "fs";
        } else {
            return "ipfs";
        }
    }

    function getAgentLogicConfigs()
        external
        view
        returns (AgentLogicConfig[] memory configs)
    {
        uint256 len = _configsNum;
        configs = new AgentLogicConfig[](len);

        for (uint256 i = 0; i < len; i++) {
            configs[i] = _agentLogicConfigs[i];
        }
    }

    function getConfigsNumber() external view returns (uint256) {
        return _configsNum;
    }
}

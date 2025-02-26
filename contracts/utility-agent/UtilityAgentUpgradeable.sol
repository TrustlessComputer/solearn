// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

contract UtilityAgentUpgradeable is IUtilityAgent, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));

    string public builtWith = "javascript"; // e.g., "python", "java"
    uint16 private _currentVersion;
    mapping(uint256 version => uint32) private _configsNum;
    mapping(uint256 version => mapping(string => string)) private _endPoints;
    mapping(uint256 version => mapping(uint256 => AgentLogicConfig))
        private _agentLogicConfigs;

    uint256[50] private __gap;

    modifier checkVersion(uint16 version) {
        _validateVersion(version);
        _;
    }

    function initialize(
        AgentLogicConfig[] calldata logicCfs,
        Endpoint[] calldata endpoints
    ) external initializer {
        __Ownable_init();

        addNewAgentConfigs(logicCfs, endpoints);
    }

    function addNewAgentConfigs(
        AgentLogicConfig[] calldata logicCfs,
        Endpoint[] calldata endpoints
    ) public virtual onlyOwner {
        uint16 version = _bumpVersion();

        uint256 cfLen = logicCfs.length;
        uint256 epLen = endpoints.length;

        for (uint256 i = 0; i < cfLen; i++) {
            _addNewAgentLogicConfig(version, logicCfs[i]);
        }

        for (uint256 i = 0; i < epLen; i++) {
            _updateEndpoint(version, endpoints[i]);
        }
    }

    function _bumpVersion() private view returns (uint16) {
        return ++_currentVersion;
    }

    function _addNewAgentLogicConfig(
        uint16 version,
        AgentLogicConfig calldata storageInfo
    ) internal virtual {
        uint256 cfNum = _getConfigsNumber(version);
        _agentLogicConfigs[version][cfNum] = storageInfo;
        emit AgentLogicConfigCreate(version, cfNum, storageInfo);
        _configsNum++;
    }

    // function updateAgentLogicConfig(
    //     uint16 version,
    //     uint256 cfIdx,
    //     AgentLogicConfig calldata cf
    // ) external onlyOwner checkVersion(version) {
    //     uint256 cfNum = _getConfigsNumber(version);

    //     if (cfIdx >= cfNum) {
    //         revert InvalidData();
    //     }
    //     _updateAgentLogicConfig(version, cfIdx, cf);
    // }

    // function _updateAgentLogicConfig(
    //     uint16 version,
    //     uint256 cfIdx,
    //     AgentLogicConfig calldata cf
    // ) internal virtual {
    //     _agentLogicConfigs[version][cfIdx] = cf;
    //     emit AgentLogicConfigUpdate(version, cfIdx, cf);
    // }

    // function removeAgentLogicConfig(
    //     uint16 version,
    //     uint256 cfIdx
    // ) external onlyOwner checkVersion(version) {
    //     uint256 cfNum = _getConfigsNumber(version);

    //     if (cfIdx >= cfNum) {
    //         revert InvalidData();
    //     }

    //     uint256 lastIdx = cfNum - 1;
    //     if (cfIdx < lastIdx) {
    //         _agentLogicConfigs[version][cfIdx] = _agentLogicConfigs[version][
    //             lastIdx
    //         ];
    //     }

    //     delete _agentLogicConfigs[version][lastIdx];
    //     _configsNum--;
    //     emit AgentLogicConfigRemove(version, cfIdx);
    // }

    function updateEndpoints(
        uint16 version,
        Endpoint[] calldata endpoints
    ) external onlyOwner checkVersion(version) {
        uint256 len = endpoints.length;

        for (uint256 i = 0; i < len; i++) {
            _updateEndpoint(version, endpoints[i]);
        }
    }

    function _updateEndpoint(
        uint16 version,
        Endpoint calldata endpoint
    ) internal virtual {
        _endPoints[version][endpoint.key] = endpoint.value;
        emit EndpointUpdate(version, endpoint);
    }

    function getEndpoints(
        uint16 version,
        string[] calldata epKeys
    ) external view returns (string[] memory epValues) {
        uint256 len = epKeys.length;
        epValues = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            epValues[i] = _endPoints[epKeys[i]];
        }
    }

    function fetchAllAgentLogic(
        uint16 version
    ) external view checkVersion(version) returns (string memory code) {
        uint256 len = _getConfigsNumber(version);
        string memory libsCode = "";
        string memory devScripts = "";

        for (uint256 cdIdx = 0; cdIdx < len; cdIdx++) {
            AgentLogicConfig memory cf = _agentLogicConfigs[version][cdIdx];
            string memory trunk = _fetchLogicByConfig(version, cf);

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

    function _fetchLogicByConfig(
        AgentLogicConfig memory cf
    ) internal view virtual returns (string memory logic) {
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
        }
        return "ipfs";
    }

    function _getConfigsNumber(uint16 version) internal view returns (uint256) {
        return _configsNum[version];
    }

    function getCurrentVersion() external view returns (uint16) {
        return _currentVersion;
    }

    function _validateVersion(uint16 version) internal view {
        if (version > _currentVersion) {
            revert InvalidVersion();
        }
    }
}

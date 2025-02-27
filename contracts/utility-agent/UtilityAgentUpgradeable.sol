// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";
contract UtilityAgentUpgradeable is IUtilityAgent, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));

    string private _implementationLanguage; // e.g., "python", "java"
    uint16 private _currentVersion;
    mapping(uint256 version => mapping(string => string)) private _endPoints;
    mapping(uint256 version => uint32) private _pointersNum;
    mapping(uint256 version => mapping(uint256 => CodePointer))
        private _codePointers;

    uint256[50] private __gap;

    modifier checkVersion(uint16 version) {
        _validateVersion(version);
        _;
    }

    function initialize(
        CodePointer[] calldata pointers,
        Endpoint[] calldata endpoints
    ) external initializer {
        __Ownable_init();

        addNewAgentConfigs(pointers, endpoints);
        _implementationLanguage = "javascript";
    }

    function addNewAgentConfigs(
        CodePointer[] calldata pointers,
        Endpoint[] calldata endpoints
    ) public virtual onlyOwner {
        uint16 version = _bumpVersion();

        uint256 pLen = pointers.length;
        uint256 epLen = endpoints.length;

        for (uint256 i = 0; i < pLen; i++) {
            _addNewCodePointer(version, pointers[i]);
        }

        for (uint256 i = 0; i < epLen; i++) {
            _updateEndpoint(version, endpoints[i]);
        }
    }

    function _bumpVersion() private returns (uint16) {
        return ++_currentVersion;
    }

    function _addNewCodePointer(
        uint16 version,
        CodePointer calldata pointer
    ) internal virtual {
        uint256 pNum = _getPointersNumber(version);

        _codePointers[version][pNum] = pointer;

        emit CodePointerCreate(version, pNum, pointer);
        _pointersNum[version]++;
    }

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
        string[] memory epKeys
    ) external view returns (string[] memory epValues) {
        uint256 len = epKeys.length;
        epValues = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            epValues[i] = _endPoints[version][epKeys[i]];
        }
    }

    function fetchAllAgentLogic(
        uint16 version
    ) external view checkVersion(version) returns (string memory code) {
        uint256 len = _getPointersNumber(version);
        string memory libsCode = "";
        string memory devScripts = "";

        for (uint256 pIdx = 0; pIdx < len; pIdx++) {
            CodePointer memory p = _codePointers[version][pIdx];
            string memory trunk = _fetchLogicByPointer(p);

            if (p.fileType == FileType.LIBRARY) {
                libsCode = string(abi.encodePacked(libsCode, trunk));
            } else if (p.fileType == FileType.DEV_SCRIPT) {
                devScripts = string(abi.encodePacked(devScripts, trunk));
            }
        }

        return _buildScript(libsCode, devScripts);
    }

    function _buildScript(
        string memory libsCode,
        string memory devScripts
    ) internal pure returns (string memory) {
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

    function _fetchLogicByPointer(
        CodePointer memory p
    ) internal view virtual returns (string memory logic) {
        if (keccak256(bytes(_getStorageMode(p))) == _IPFS_SIG) {
            logic = p.fileName; // return the IPFS hash
        } else {
            logic = IFileStore(p.retrieveAddress).getFile(p.fileName).read();
        }
    }

    function _getStorageMode(
        CodePointer memory p
    ) internal view virtual returns (string memory) {
        if (p.retrieveAddress != address(0)) {
            return "fs";
        }
        return "ipfs";
    }

    function _getPointersNumber(
        uint16 version
    ) internal view returns (uint256) {
        return _pointersNum[version];
    }

    function getCurrentVersion() external view returns (uint16) {
        return _currentVersion;
    }

    function _validateVersion(uint16 version) internal view {
        if (version > _currentVersion) {
            revert InvalidVersion();
        }
    }

    function getImplementationLanguage() external view returns (string memory) {
        return _implementationLanguage;
    }
}

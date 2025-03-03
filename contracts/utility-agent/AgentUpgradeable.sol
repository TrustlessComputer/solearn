// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable, ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IAgent} from "./IAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";
import "hardhat/console.sol";

contract AgentUpgradeable is IAgent, EIP712Upgradeable, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));
    bytes32 private constant SIGN_DATA_TYPEHASH =
        keccak256(
            "SignData(CodePointer[] pointers,address[] depsAgents,bool isOnchain,uint16 currentVersion)CodePointer(address retrieveAddress,uint8 fileType,string fileName)"
        );

    string private _codeLanguage; // e.g., "python", "javascript"...
    address private _agentOwner;
    uint16 private _currentVersion;

    mapping(uint256 version => bool) private _isOnchain;
    mapping(uint256 version => uint256) private _pointersNum;
    mapping(uint256 version => mapping(uint256 => CodePointer))
        private _codePointers;
    mapping(uint256 version => address[]) private _depsAgents;

    uint256[50] private __gap;

    modifier checkVersion(uint16 version) {
        _validateVersion(version);
        _;
    }

    modifier onlyAgentOwner() {
        if (msg.sender != _agentOwner) revert Unauthenticated();
        _;
    }

    function initialize(
        string memory agentName,
        string memory agentVersion,
        string memory codeLanguage,
        CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        address agentOwner,
        bool isOnchain
    ) external initializer {
        if (agentOwner == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init();
        __EIP712_init(agentName, agentVersion);

        _codeLanguage = codeLanguage;
        _agentOwner = agentOwner;
        _publishAgentCode(pointers, depsAgents, isOnchain);
    }

    function publishAgentCode(
        CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        bool isOnchain
    ) external virtual onlyAgentOwner returns (uint16) {
        return _publishAgentCode(pointers, depsAgents, isOnchain);
    }

    function publishAgentCodeWithSignature(
        CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        bool isOnchain,
        bytes calldata signature
    ) external virtual returns (uint16) {
        bytes32 digest = getHashToSign(pointers, depsAgents, isOnchain);
        if (ECDSAUpgradeable.recover(digest, signature) != _agentOwner) {
            revert Unauthenticated();
        }
        return _publishAgentCode(pointers, depsAgents, isOnchain);
    }

    function _publishAgentCode(
        CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        bool isOnchain
    ) internal virtual returns (uint16) {
        if (pointers.length == 0) revert InvalidData();

        uint16 version = _bumpVersion();
        _isOnchain[version] = isOnchain;

        uint256 pLen = pointers.length;
        for (uint256 i = 0; i < pLen; i++) {
            if (bytes(pointers[i].fileName).length == 0) {
                revert InvalidData();
            }
            _addNewCodePointer(version, pointers[i]);
        }

        uint256 depsLen = depsAgents.length;
        for (uint256 i = 0; i < depsLen; i++) {
            if (depsAgents[i] == address(0)) {
                revert ZeroAddress();
            }
            _depsAgents[version].push(depsAgents[i]);
        }

        return version;
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

        emit CodePointerCreated(version, pNum, pointer);
        _pointersNum[version]++;
    }

    function getDepsAgents(
        uint16 version
    ) external view checkVersion(version) returns (address[] memory) {
        return _depsAgents[version];
    }

    function isOnchain(uint256 version) external view returns (bool) {
        return _isOnchain[version];
    }

    function getAgentCode(
        uint16 version
    ) external view checkVersion(version) returns (string memory code) {
        uint256 len = _getPointersNumber(version);
        string memory libsCode = "";
        string memory mainScripts = "";

        for (uint256 pIdx = 0; pIdx < len; pIdx++) {
            CodePointer memory p = _codePointers[version][pIdx];

            string memory codeChunk = _getCodeByPointer(p);

            if (p.fileType == FileType.LIBRARY) {
                libsCode = _concatStrings(libsCode, codeChunk);
            } else if (p.fileType == FileType.MAIN_SCRIPT) {
                mainScripts = _concatStrings(mainScripts, codeChunk);
            }
        }

        return _concatStrings(libsCode, mainScripts);
    }

    function _concatStrings(
        string memory a,
        string memory b
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function _getCodeByPointer(
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

    function getCodeLanguage() external view returns (string memory) {
        return _codeLanguage;
    }

    function getHashToSign(
        CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        bool isOnchain
    ) public view virtual returns (bytes32) {
        bytes32 CODEPOINTER_TYPEHASH = keccak256(
            "CodePointer(address retrieveAddress,uint8 fileType,string fileName)"
        );

        bytes32[] memory pointerHashes = new bytes32[](pointers.length);

        uint256 pLen = pointers.length;
        for (uint i = 0; i < pLen; i++) {
            pointerHashes[i] = keccak256(
                abi.encode(
                    CODEPOINTER_TYPEHASH,
                    pointers[i].retrieveAddress,
                    pointers[i].fileType,
                    keccak256(bytes(pointers[i].fileName))
                )
            );
        }

        bytes32 pointersHash = keccak256(abi.encodePacked(pointerHashes));
        bytes32 depsAgentsHash = keccak256(abi.encodePacked(depsAgents));

        bytes32 structHash = keccak256(
            abi.encode(
                SIGN_DATA_TYPEHASH,
                pointersHash,
                depsAgentsHash,
                isOnchain,
                _currentVersion
            )
        );

        return _hashTypedDataV4(structHash);
    }
}

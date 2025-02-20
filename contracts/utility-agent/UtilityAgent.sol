// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUtilityAgent, ICommonAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

abstract contract UtilityAgent is IUtilityAgent, Ownable {
    bytes32 immutable _IPFS_SIG;

    string internal _systemPrompt;
    StorageInfo internal _storageInfo;
    mapping(bytes32 uuid => RequestInfo) internal _requests;

    modifier notZeroAddress(address addr) {
        _validateAddress(addr);
        _;
    }

    constructor(
        string memory systemPrompt_,
        bytes memory storageInfo_
    ) Ownable() {
        _systemPrompt = systemPrompt_;
        _saveStorageInfo(storageInfo_);

        _IPFS_SIG = keccak256(bytes("ipfs"));
    }

    function _saveStorageInfo(bytes memory storageInfo) internal virtual {
        if (storageInfo.length < 20) {
            revert InvalidData();
        }

        (address fsContractAddress, string memory filename) = abi.decode(
            storageInfo,
            (address, string)
        );
        _storageInfo = StorageInfo(fsContractAddress, filename);
    }

    function _validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    function _updateFileName(string memory filename) internal virtual {
        _storageInfo.filename = filename;
    }

    function updateFileName(string memory filename) external virtual onlyOwner {
        _updateFileName(filename);
    }

    function updateSystemPrompt(
        string memory systemPrompt
    ) external virtual onlyOwner {
        _systemPrompt = systemPrompt;
        emit SystemPromptUpdate(systemPrompt);
    }

    function getSystemPrompt() external view returns (string memory) {
        return _systemPrompt;
    }

    function prompt(
        bytes memory request
    ) external payable virtual returns (uint256);

    function prompt(
        bytes32 uuid,
        bytes calldata request
    ) external payable virtual returns (uint256);

    function forward(
        bytes32 uuid,
        address dstAgent,
        bytes memory request
    ) external payable returns (uint256 dstActionId) {
        if (_requests[uuid].agentAddress != address(0)) {
            revert DuplicateUuid();
        }

        bytes memory forwardData = _buildForwardData(request);
        dstActionId = ICommonAgent(dstAgent).prompt(uuid, forwardData);

        _requests[uuid] = RequestInfo(dstAgent, uint64(dstActionId));

        emit ForwardPerformed(uuid, dstActionId, msg.sender, forwardData);
    }

    function _buildForwardData(
        bytes memory request
    ) internal view returns (bytes memory) {
        return abi.encodePacked(bytes(_systemPrompt), request);
    }

    function getResultById(
        bytes32 uuid
    ) external view virtual returns (bytes memory);

    function getResultById(
        uint256 id
    ) external view virtual returns (bytes memory);

    function fetchCode() external view virtual returns (string memory logic) {
        if (keccak256(bytes(getStorageMode())) == _IPFS_SIG) {
            logic = _storageInfo.filename; // return the IPFS hash
        } else {
            logic = IFileStore(_storageInfo.contractAddress)
                .getFile(_storageInfo.filename)
                .read();
        }
    }

    function getStorageMode() public view virtual returns (string memory) {
        if (_storageInfo.contractAddress != address(0)) {
            return "fs";
        } else {
            return "ipfs";
        }
    }

    function getStorageInfo()
        external
        view
        virtual
        returns (StorageInfo memory)
    {
        return _storageInfo;
    }

    function getFileStorageChunkInfo()
        external
        view
        virtual
        returns (File memory file)
    {
        file = IFileStore(_storageInfo.contractAddress).getFile(
            _storageInfo.filename
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

contract UtilityAgentUpgradeable is IUtilityAgent, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));

    string private _systemPrompt;
    StorageInfo private _storageInfo;

    uint256[50] private __gap;

    function initialize(
        string memory systemPrompt_,
        bytes memory storageInfo_
    ) external initializer {
        __Ownable_init();
        _systemPrompt = systemPrompt_;
        _saveStorageInfo(storageInfo_);
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

    function updateFileName(string memory filename) external onlyOwner {
        _updateFileName(filename);
    }

    function _updateFileName(string memory filename) internal virtual {
        _storageInfo.filename = filename;
        emit FileNameUpdate(filename);
    }

    function updateSystemPrompt(string memory systemPrompt) external onlyOwner {
        _updateSystemPrompt(systemPrompt);
    }

    function _updateSystemPrompt(string memory systemPrompt) internal virtual {
        _systemPrompt = systemPrompt;
        emit SystemPromptUpdate(systemPrompt);
    }

    function getSystemPrompt() external view returns (string memory) {
        return _systemPrompt;
    }

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

    function getStorageInfo() external view returns (StorageInfo memory) {
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

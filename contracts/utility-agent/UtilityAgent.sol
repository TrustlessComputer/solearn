// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHybridModel} from "../interfaces/IHybridModel.sol";
import {IWorkerHub} from "../interfaces/IWorkerHub.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

abstract contract UtilityAgent is IUtilityAgent, Ownable {
    bytes32 immutable __IPFS_SIG;
    StorageInfo internal _storageInfo;
    address internal _promptScheduler;
    address internal _modelAddress;
    string internal _systemPrompt;

    constructor(
        address promptScheduler_,
        address modelAddress_,
        string memory systemPrompt_,
        bytes memory storageInfo_
    ) {
        if (promptScheduler_ == address(0) || modelAddress_ == address(0)) {
            revert InvalidAddress();
        }

        _promptScheduler = promptScheduler_;
        _modelAddress = modelAddress_;
        _systemPrompt = systemPrompt_;
        _saveStorageInfo(storageInfo_);

        __IPFS_SIG = keccak256(abi.encodePacked("ipfs"));
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

    function _updateFileName(string memory filename) internal virtual {
        _storageInfo.filename = filename;
    }

    function updateFileName(string memory filename) external virtual onlyOwner {
        _updateFileName(filename);
    }

    function updatePromptScheduler(
        address promptScheduler
    ) external virtual onlyOwner {
        _promptScheduler = promptScheduler;

        emit PromptSchedulerHubUpdate(promptScheduler);
    }

    function getPromptSchedulerAddress() external view returns (address) {
        return _promptScheduler;
    }

    function updateModelAddress(
        address modelAddress
    ) external virtual onlyOwner {
        _modelAddress = modelAddress;

        emit ModelUpdate(modelAddress);
    }

    function getModelAddress() external view returns (address) {
        return _modelAddress;
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
        bytes calldata request
    ) external virtual returns (uint256 inferId) {
        inferId = IHybridModel(_modelAddress).infer(request);

        emit PromptPerformed(msg.sender, inferId, request);
    }

    function getResultById(uint256 id) external view returns (bytes memory) {
        return IWorkerHub(_promptScheduler).getInferenceInfo(id).output;
    }

    function fetchCode() external view virtual returns (string memory logic) {
        if (keccak256(abi.encodePacked(getStorageMode())) == __IPFS_SIG) {
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

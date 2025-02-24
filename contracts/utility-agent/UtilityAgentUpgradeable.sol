// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUtilityAgent} from "./IUtilityAgent.sol";
import {IFileStore, File} from "./IFileStore.sol";

contract UtilityAgentUpgradeable is IUtilityAgent, OwnableUpgradeable {
    bytes32 private constant _IPFS_SIG = keccak256(bytes("ipfs"));

    string private _systemPrompt;
    mapping(string => string) private _endPoints;
    uint32 private _configsNum;
    mapping(uint256 => StorageInfo) private _storageInfos;

    uint256[50] private __gap;

    /**
     * @notice Initializes the contract.
     * @param systemPrompt_ The initial system prompt.
     * @param storageInfos_ The initial storage information.
     */
    function initialize(
        string memory systemPrompt_,
        StorageInfo[] calldata storageInfos_
    ) external initializer {
        __Ownable_init();
        _systemPrompt = systemPrompt_;

        uint256 len = storageInfos_.length;
        for (uint256 i = 0; i < len; i++) {
            _addNewStorageInfo(storageInfos_[i]);
        }
    }

    /**
     * @notice Adds new storage information.
     * @param storageInfo The storage information to add.
     */
    function _addNewStorageInfo(
        StorageInfo calldata storageInfo
    ) internal virtual {
        _storageInfos[_configsNum] = storageInfo;
        emit StorageInfoUpdate(_configsNum, storageInfo);
        _configsNum++;
    }

    /**
     * @notice Updates the storage information for a given index.
     * @param cfIndex The index of the storage information to update.
     * @param storageInfo The new storage information.
     */
    function updateStorageInfo(
        uint256 cfIndex,
        StorageInfo calldata storageInfo
    ) external onlyOwner {
        if (cfIndex >= _configsNum) {
            revert InvalidData();
        }
        _updateStorageInfo(cfIndex, storageInfo);
    }

    /**
     * @notice Updates the storage information for a given index.
     * @param cfIndex The index of the storage information to update.
     * @param storageInfo The new storage information.
     */
    function _updateStorageInfo(
        uint256 cfIndex,
        StorageInfo calldata storageInfo
    ) internal virtual {
        _storageInfos[cfIndex] = storageInfo;
        emit StorageInfoUpdate(cfIndex, storageInfo);
    }

    /**
     * @notice Updates the system prompt.
     * @param systemPrompt The new system prompt.
     */
    function updateSystemPrompt(
        string calldata systemPrompt
    ) external onlyOwner {
        _updateSystemPrompt(systemPrompt);
    }

    /**
     * @notice Updates the system prompt.
     * @param systemPrompt The new system prompt.
     */
    function _updateSystemPrompt(
        string calldata systemPrompt
    ) internal virtual {
        _systemPrompt = systemPrompt;
        emit SystemPromptUpdate(systemPrompt);
    }

    /**
     * @notice Gets the system prompt.
     * @return The system prompt.
     */
    function getSystemPrompt() external view returns (string memory) {
        return _systemPrompt;
    }

    /**
     * @notice Fetches all file codes.
     * @return filename An array of filenames.
     * @return logic An array of file contents.
     */
    function fetchAllFileCodes()
        external
        view
        virtual
        returns (string[] memory filename, string[] memory logic)
    {
        uint256 len = _configsNum;
        filename = new string[](len);
        logic = new string[](len);
        for (uint256 i = 0; i < len; i++) {
            filename[i] = _storageInfos[i].filename;
            logic[i] = fetchFileCodeFromConfig(_storageInfos[i]);
        }
    }

    /**
     * @notice Fetches the file code from a given storage configuration.
     * @param config The storage configuration.
     * @return logic The file content.
     */
    function fetchFileCodeFromConfig(
        StorageInfo memory config
    ) public view virtual returns (string memory logic) {
        if (keccak256(bytes(getStorageMode(config))) == _IPFS_SIG) {
            logic = config.filename; // return the IPFS hash
        } else {
            logic = IFileStore(config.contractAddress)
                .getFile(config.filename)
                .read();
        }
    }

    /**
     * @notice Gets the storage mode for a given storage configuration.
     * @param config The storage configuration.
     * @return The storage mode ("fs" or "ipfs").
     */
    function getStorageMode(
        StorageInfo memory config
    ) public view virtual returns (string memory) {
        if (config.contractAddress != address(0)) {
            return "fs";
        } else {
            return "ipfs";
        }
    }

    /**
     * @notice Gets all storage configurations.
     * @return configs An array of storage configurations.
     */
    function getStorageInfo()
        external
        view
        returns (StorageInfo[] memory configs)
    {
        uint256 len = _configsNum;
        configs = new StorageInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            configs[i] = _storageInfos[i];
        }
    }

    /**
     * @notice Updates multiple endpoints.
     * @param keys An array of endpoint keys.
     * @param values An array of endpoint values.
     */
    function updateEndpoints(
        string[] calldata keys,
        string[] calldata values
    ) external onlyOwner {
        uint256 len = keys.length;
        for (uint256 i = 0; i < len; i++) {
            updateEndpoint(keys[i], values[i]);
        }
    }

    /**
     * @notice Updates a single endpoint.
     * @param key The endpoint key.
     * @param value The endpoint value.
     */
    function updateEndpoint(
        string calldata key,
        string calldata value
    ) public virtual onlyOwner {
        _endPoints[key] = value;
        emit EndpointUpdate(key, value);
    }

    /**
     * @notice Gets the value of an endpoint.
     * @param key The endpoint key.
     * @return value The endpoint value.
     */
    function getEndpoint(
        string calldata key
    ) external view returns (string memory value) {
        value = _endPoints[key];
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ModelLoadBalancerStorage, Set} from "./storages/ModelLoadBalancerStorage.sol";
import {IStakingHub} from "./interfaces/IStakingHub.sol";
import {IHybridModel} from "./interfaces/IHybridModel.sol";

contract ModelLoadBalancer is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ModelLoadBalancerStorage
{
    using Set for Set.AddressSet;
    string private constant VERSION = "v0.0.1";

    function initialize(address stakingHub_) public initializer {
        if (stakingHub_ == address(0)) revert InvalidData();

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _stakingHub = stakingHub_;
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function createGroup(
        string memory name,
        address[] calldata clusters
    ) external onlyOwner {
        bytes32 groupId = keccak256(abi.encodePacked(name));

        if (bytes(_groups[groupId].name).length != 0)
            revert ClusterGroupAlreadyExist(name);

        _groups[groupId].anchorPoint = 0;
        _groups[groupId].name = name;

        uint256 clusterLen = clusters.length;

        if (clusterLen > 0) {
            for (uint256 i = 0; i < clusterLen; i++) {
                address cluster = clusters[i];
                if (cluster == address(0)) revert InvalidData();

                _groups[groupId].clusters.insert(cluster);
                emit ClusterAdded(groupId, cluster);
            }
        }

        emit ClusterGroupCreated(groupId, name);
    }

    function removeGroup(string calldata name) external onlyOwner {
        bytes32 id = _findGroup(name);
        delete _groups[id];
        emit ClusterGroupRemoved(id, name);
    }

    function addClustersToGroup(
        string calldata groupName,
        address[] calldata clusters
    ) external onlyOwner {
        if (clusters.length == 0) revert InvalidData();

        bytes32 groupId = _findGroup(groupName);

        uint256 clusterLen = clusters.length;
        for (uint256 i = 0; i < clusterLen; i++) {
            address cluster = clusters[i];

            _groups[groupId].clusters.insert(cluster);
            emit ClusterAdded(groupId, cluster);
        }
    }

    function removeClustersFromGroup(
        string calldata groupName,
        address[] calldata clusters
    ) external onlyOwner {
        if (clusters.length == 0) revert InvalidData();

        bytes32 id = _findGroup(groupName);

        uint256 clusterLen = clusters.length;
        for (uint256 i = 0; i < clusterLen; i++) {
            address cluster = clusters[i];

            _groups[id].clusters.erase(cluster);
            emit ClusterRemoved(id, cluster);
        }
    }

    function getClustersOfGroup(
        string memory name
    ) external view returns (address[] memory) {
        return _groups[keccak256(abi.encodePacked(name))].clusters.values;
    }

    function getClustersGroupInfo(
        string memory name
    ) external view returns (string memory, uint16, address[] memory) {
        bytes32 id = keccak256(abi.encodePacked(name));
        return (
            _groups[id].name,
            _groups[id].anchorPoint,
            _groups[id].clusters.values
        );
    }

    function infer(
        string calldata groupName,
        bytes calldata data,
        bool rawFlag
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        if (data.length == 0) revert InvalidData();

        bytes32 groupId = _findGroup(groupName);
        uint256 numOfCluster = _groups[groupId].clusters.size();
        if (numOfCluster == 0) revert InvalidData();

        uint16 anchorPoint = _groups[groupId].anchorPoint;
        uint16 originPoint = anchorPoint;
        address cluster;

        while (true) {
            anchorPoint++;

            if (anchorPoint >= numOfCluster) anchorPoint = 0;

            cluster = _groups[groupId].clusters.values[anchorPoint];

            if (IStakingHub(_stakingHub).isActiveModel(cluster)) {
                break;
            }

            if (anchorPoint == originPoint) {
                revert InactiveClusterGroup();
            }
        }
        _groups[groupId].anchorPoint = anchorPoint;

        uint256 inferId;
        if (rawFlag) {
            inferId = IHybridModel(cluster).infer{value: msg.value}(
                data,
                msg.sender,
                rawFlag
            );
        } else {
            inferId = IHybridModel(cluster).infer{value: msg.value}(
                data,
                msg.sender
            );
        }

        emit InferencePerformed(msg.sender, inferId, groupId, cluster, data);
        return inferId;
    }

    function _findGroup(string calldata name) internal view returns (bytes32) {
        bytes32 id = keccak256(abi.encodePacked(name));
        if (bytes(_groups[id].name).length == 0)
            revert ClusterGroupNotFound(name);

        return id;
    }

    function getStakingHubAddress() external view returns (address) {
        return _stakingHub;
    }
}

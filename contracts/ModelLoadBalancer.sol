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
        address[] calldata subnets
    ) external onlyOwner {
        bytes32 groupId = keccak256(abi.encodePacked(name));

        if (bytes(_groups[groupId].name).length != 0)
            revert SubnetGroupAlreadyExist(name);

        _groups[groupId].anchorPoint = 0;
        _groups[groupId].name = name;

        uint256 subnetLen = subnets.length;

        if (subnetLen > 0) {
            for (uint256 i = 0; i < subnetLen; i++) {
                address subnet = subnets[i];
                if (subnet == address(0)) revert InvalidData();

                _groups[groupId].subnets.insert(subnet);
                emit SubnetAdded(groupId, subnet);
            }
        }

        emit GroupCreated(groupId, name);
    }

    function removeGroup(string calldata name) external onlyOwner {
        bytes32 id = _findGroup(name);
        delete _groups[id];
        emit GroupRemoved(id, name);
    }

    function addSubnetToGroup(
        string calldata groupName,
        address[] calldata subnets
    ) external onlyOwner {
        if (subnets.length == 0) revert InvalidData();

        bytes32 groupId = _findGroup(groupName);

        uint256 subnetLen = subnets.length;
        for (uint256 i = 0; i < subnetLen; i++) {
            address subnet = subnets[i];

            _groups[groupId].subnets.insert(subnet);
            emit SubnetAdded(groupId, subnet);
        }
    }

    function removeSubnetFromGroup(
        string calldata groupName,
        address[] calldata subnets
    ) external onlyOwner {
        if (subnets.length == 0) revert InvalidData();

        bytes32 subnetId = _findGroup(groupName);

        uint256 subnetLen = subnets.length;
        for (uint256 i = 0; i < subnetLen; i++) {
            address subnet = subnets[i];

            _groups[subnetId].subnets.erase(subnet);
            emit SubnetRemoved(subnetId, subnet);
        }
    }

    function getSubnetsOfGroup(
        string memory name
    ) external view returns (address[] memory) {
        return _groups[keccak256(abi.encodePacked(name))].subnets.values;
    }

    function getSubnetsGroupInfo(
        string memory name
    ) external view returns (string memory, uint16, address[] memory) {
        bytes32 id = keccak256(abi.encodePacked(name));
        return (
            _groups[id].name,
            _groups[id].anchorPoint,
            _groups[id].subnets.values
        );
    }

    function infer(
        string calldata groupName,
        bytes calldata data,
        bool rawFlag
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        if (data.length == 0) revert InvalidData();

        bytes32 groupId = _findGroup(groupName);
        uint256 numOfSubnet = _groups[groupId].subnets.size();
        if (numOfSubnet == 0) revert InvalidData();

        uint16 anchorPoint = _groups[groupId].anchorPoint;
        uint16 originPoint = anchorPoint;
        address subnet;

        while (true) {
            anchorPoint++;

            if (anchorPoint >= numOfSubnet) anchorPoint = 0;

            subnet = _groups[groupId].subnets.values[anchorPoint];

            if (IStakingHub(_stakingHub).isActiveModel(subnet)) {
                break;
            }

            if (anchorPoint == originPoint) {
                revert InactiveSubnetGroup();
            }
        }
        _groups[groupId].anchorPoint = anchorPoint;

        uint256 inferId;
        if (rawFlag) {
            inferId = IHybridModel(subnet).infer{value: msg.value}(
                data,
                msg.sender,
                rawFlag
            );
        } else {
            inferId = IHybridModel(subnet).infer{value: msg.value}(
                data,
                msg.sender
            );
        }

        emit InferencePerformed(msg.sender, inferId, groupId, subnet, data);
        return inferId;
    }

    function _findGroup(string calldata name) internal view returns (bytes32) {
        bytes32 id = keccak256(abi.encodePacked(name));
        if (bytes(_groups[id].name).length == 0) revert GroupNotFound(name);

        return id;
    }

    function getStakingHubAddress() external view returns (address) {
        return _stakingHub;
    }
}

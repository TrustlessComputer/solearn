// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Set} from "../lib/Set.sol";

interface IModelLoadBalancer {
    struct ClusterGroup {
        uint16 anchorPoint;
        string name;
        Set.AddressSet clusters;
    }

    event ClusterGroupCreated(bytes32 indexed groupId, string name);
    event ClusterGroupRemoved(bytes32 indexed groupId, string name);
    event ClusterAdded(bytes32 indexed groupId, address indexed cluster);
    event ClusterRemoved(bytes32 indexed groupId, address indexed cluster);
    event InferencePerformed(
        address indexed caller,
        uint256 indexed inferenceId,
        bytes32 indexed groupId,
        address cluster,
        bytes data
    );

    error ClusterGroupAlreadyExist(string name);
    error ClusterGroupNotFound(string name);
    error InvalidData();
    error InactiveClusterGroup();

    function infer(
        string memory groupName,
        bytes calldata data,
        bool rawFlag
    ) external payable returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Set} from "../lib/Set.sol";

interface IModelLoadBalancer {
    struct SubnetGroup {
        uint16 anchorPoint;
        string name;
        Set.AddressSet subnets;
    }

    event GroupCreated(bytes32 indexed groupId, string name);
    event GroupRemoved(bytes32 indexed groupId, string name);
    event SubnetAdded(bytes32 indexed groupId, address indexed subnet);
    event SubnetRemoved(bytes32 indexed groupId, address indexed subnet);
    event InferencePerformed(
        address indexed caller,
        uint256 indexed inferenceId,
        bytes32 indexed groupId,
        address subnet,
        bytes data
    );

    error SubnetGroupAlreadyExist(string name);
    error GroupNotFound(string name);
    error InvalidData();
    error InactiveSubnetGroup();

    function infer(
        string memory groupName,
        bytes calldata data,
        bool rawFlag
    ) external payable returns (uint256);
}

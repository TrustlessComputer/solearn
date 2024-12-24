// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IModelLoadBalancer, Set} from "../interfaces/IModelLoadBalancer.sol";

abstract contract ModelLoadBalancerStorage is IModelLoadBalancer {
    address internal _stakingHub;
    mapping(bytes32 => SubnetGroup) internal _groups;

    uint256[50] private __gap;
}

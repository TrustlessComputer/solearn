// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHybridGateway} from "../interfaces/IHybridGateway.sol";

abstract contract HybridGatewayStorage is IHybridGateway {
    uint256 public identifier;

    string public name;
    string public metadata;

    address public workerHub;
    address public gatewayCollection;

    uint256[49] private __gap;
}

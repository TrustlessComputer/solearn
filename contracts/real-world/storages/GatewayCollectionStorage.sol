// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IGatewayCollection} from "../interfaces/IGatewayCollection.sol";

abstract contract GatewayCollectionStorage is IGatewayCollection {
    mapping(uint256 => address) internal gateways;
    uint256 public nextGatewayId;
    uint256 public mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;

    uint256[49] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IModelCollection} from "../interfaces/IModelCollection.sol";

abstract contract ModelCollectionStorage is IModelCollection {
    mapping(uint256 => address) internal models;
    mapping(bytes32 => bool) internal dataSignUsed;
    uint256 public nextModelId;
    uint256 public mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IModelCollectionERC20} from "../interfaces/IModelCollectionERC20.sol";

abstract contract ModelCollectionERC20Storage is IModelCollectionERC20 {
    mapping(uint256 => address) internal models;
    uint256 public nextModelId;
    uint256 public mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;

    address public token;

    uint256[48] private __gap;
}

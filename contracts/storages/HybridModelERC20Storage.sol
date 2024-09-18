// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHybridModelERC20} from "../interfaces/IHybridModelERC20.sol";

abstract contract HybridModelERC20Storage is IHybridModelERC20 {
    uint256 public identifier;

    string public name;
    string public metadata;

    address public workerHub;

    uint256[50] private __gap;
}

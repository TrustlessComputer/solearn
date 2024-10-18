// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISystemPromptManager} from "../interfaces/ISystemPromptManager.sol";

abstract contract SystemPromptManagerStorage is ISystemPromptManager {
    mapping(uint256 => TokenMetaData) internal datas;
    uint256 public nextTokenId;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;
    address public hybridModel;

    // fee 
    mapping (address => uint) public fees;

    uint256[49] private __gap;
}

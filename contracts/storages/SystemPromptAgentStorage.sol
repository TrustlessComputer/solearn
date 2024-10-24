// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISystemPromptAgent} from "../interfaces/ISystemPromptAgent.sol";

abstract contract SystemPromptAgentStorage is ISystemPromptAgent {
    mapping(uint256 => TokenMetaData) internal datas;
    uint256 public nextTokenId;
    uint256 public mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;
    address public hybridModel;

    // fee
    mapping(address => uint) public earnedFees;

    uint256[50] private __gap;
}

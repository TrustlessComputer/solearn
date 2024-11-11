// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISystemPromptManager} from "../interfaces/ISystemPromptManager.sol";

abstract contract SystemPromptManagerStorage is ISystemPromptManager {
    mapping(uint256 nftId => TokenMetaData) internal datas;
    uint256 public nextTokenId;
    uint256 public mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;
    address workerHub;
    address public hybridModel;

    // fee
    mapping(address nftOwner => uint256) public earnedFees;
    mapping(uint256 nftId => uint256) public poolBalance;
    mapping(address nftOwner => uint256) public nonce;
    mapping(address nftOwner => uint256) public nonceForUri;

    uint256[48] private __gap;
}

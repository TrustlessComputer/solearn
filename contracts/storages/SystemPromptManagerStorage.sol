// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAI721Upgradeable} from "../standardUpgradeable/interfaces/IAI721Upgradeable.sol";
import {ISystemPromptManager} from "../interfaces/ISystemPromptManager.sol";

abstract contract SystemPromptManagerStorage is ISystemPromptManager {
    mapping(uint256 nftId => IAI721Upgradeable.TokenMetaData) internal datas;
    uint256 _nextTokenId;
    uint256 internal mintPrice;
    address _royaltyReceiver;
    uint16 _royaltyPortion;

    mapping(address => bool) public isManager;
    address public workerHub;
    address public stakingHub;

    // fee
    mapping(address nftOwner => uint256) internal earnedFees;
    mapping(uint256 agentId => uint256) public poolBalance;
    mapping(address nftOwner => uint256) internal nonce;
    mapping(address nftOwner => mapping(bytes signature => bool))
        public signaturesUsed;

    mapping(uint256 agentId => bytes[]) internal missionsOf;
    address squadManager;

    address public feeTokenAddr;
    address public cryptoAiDataAddr;
    uint256 public nextAgentId;
    mapping (uint256 agentId => AgentInfo) agentInfo;
    mapping (uint256 agentId => AgentRating) public agentRating;
    
    mapping (uint256 tokenId => uint256 agentId) tokenIdToAgentId;


    uint256[46] __gap;
}

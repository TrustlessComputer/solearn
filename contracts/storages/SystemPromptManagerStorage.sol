// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISystemPromptManager} from "../interfaces/ISystemPromptManager.sol";
import {Set} from "../lib/Set.sol";

abstract contract SystemPromptManagerStorage is ISystemPromptManager {
    mapping(uint256 nftId => TokenMetaData) internal datas;
    uint256 public nextTokenId;
    uint256 internal mintPrice;
    address public royaltyReceiver;
    uint16 public royaltyPortion;

    mapping(address => bool) public isManager;
    address public workerHub;
    address public hybridModel;

    // fee
    mapping(address nftOwner => uint256) internal earnedFees;
    mapping(uint256 nftId => uint256) public poolBalance;
    mapping(address nftOwner => uint256) internal nonce;
    mapping(address nftOwner => mapping(bytes signature => bool))
        public signaturesUsed;

    uint256 public currentSquadId;
    mapping(uint256 squadId => address) public squadOwner;
    mapping(uint256 squadId => Set.Uint256Set) internal squadToAgentIds;
    mapping(address squadOwner => uint256) public squadBalance;
    mapping(address squadOwner => mapping(uint256 index => uint256 squadId))
        internal ownedSquads;
    mapping(uint256 squadId => uint256) internal ownedSquadsIndex;
    uint256[] internal _allSquads;
    mapping(uint256 => uint256) internal _allSquadsIndex;

    mapping(uint256 agentId => uint256) internal agentToSquadId;

    uint256[48] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

import {Random} from "../lib/Random.sol";
import {Set} from "../lib/Set.sol";

abstract contract PromptSchedulerStorage is IWorkerHub {
    Random.Randomizer internal randomizer;

    uint256 public inferenceNumber;
    mapping(uint256 => Inference) internal inferences;
    mapping(address => Set.Uint256Set) internal inferencesByMiner;

    address internal l2Owner;
    address internal treasury;
    uint16 internal feeL2Percentage;
    uint16 internal feeTreasuryPercentage;
    uint16 internal feeRatioMinerValidator;
    uint40 internal submitDuration;
    uint40 internal commitDuration;
    uint40 internal revealDuration;
    uint8 internal minerRequirement;
    DAOTokenPercentage internal daoTokenPercentage;

    uint256 internal daoTokenReward; // per request (in wei)

    mapping(address => address) internal referrerOf;

    mapping(uint256 inferId => DAOTokenReceiverInfor[])
        internal daoReceiversInfo;

    address internal wEAI;
    address internal stakingHub;
    address internal daoToken;

    uint256[100] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerHub, Set} from "../interfaces/IWorkerHub.sol";

abstract contract PromptSchedulerStorage is IWorkerHub {
    address public _wEAI;
    address public _stakingHub;

    uint64 public _inferenceNumber;
    mapping(uint64 => Inference) internal _inferences;
    mapping(address => Set.Uint256Set) internal _inferencesByMiner;

    uint16 public _feeRatioMinerValidator;
    uint40 public _submitDuration;
    uint40 internal _commitDuration;
    uint40 internal _revealDuration;
    uint8 public _minerRequirement;

    mapping(uint32 modelId => mapping(uint64 batchId => BatchInfo))
        internal _batchInfos;
    uint256 public _lastBatchTimestamp;
    uint256 public _batchPeriod;

    uint256[100] private __gap;
}

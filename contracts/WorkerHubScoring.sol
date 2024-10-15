// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WorkerHub} from "./WorkerHub.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {ICallBack} from "./interfaces/ICallBack.sol";
import {Set} from "./lib/Set.sol";

contract WorkerHubScoring is WorkerHub {
    using Set for Set.Uint256Set;

    struct InferExtended {
        address sender;
        address destination;
        uint inferId;
    }

    event Log(string);

    // // define storage here
    address internal workHubAddr;
    // inter => InferExtended
    mapping(uint => InferExtended) internal extendInferInfo;

    uint256[100] private __gap2;

    // define functions
    function setupScoringVar(address payable _workhubAddr) external onlyOwner {
        workHubAddr = _workhubAddr;
    }

    function inferWithCallback(
        uint originInferId,
        bytes calldata _input,
        address _creator,
        address callback
    ) external payable override returns (uint256 inferid) {
        inferid = infer(_input, _creator);

        extendInferInfo[inferid] = InferExtended(
            msg.sender,
            callback,
            originInferId
        );
    }

    function _validateEnoughFeeToUse(
        uint256 _modelMinimumFee
    ) internal view override returns (uint256) {
        if (msg.value < _modelMinimumFee) revert("Fee too low");

        return 0;
    }

    function _fallBackWorkerHub(
        uint originInferId,
        bytes memory data
    ) internal {
        try ICallBack(workHubAddr).resultReceived(originInferId, data) {
            emit Log("call sucess");
        } catch {
            emit Log("external call failed");
        }
    }

    function _fallBack(address dest, bytes memory data) internal {
        try ICallBack(dest).resultReceived(data) {
            emit Log("call sucess");
        } catch {
            emit Log("external call failed");
        }
    }

    // todo: issace add more logic
    function _filterCommitment(
        uint256 _inferenceId
    ) internal override returns (bool) {
        (bytes32 mostVotedDigest, uint8 maxCount) = _findMostVotedDigest(
            _inferenceId
        );

        // Check the maxCount is greater than the voting requirement
        if (
            maxCount <
            _getThresholdValue(assignmentsByInference[_inferenceId].size())
        ) {
            return false;
        }

        uint256[] memory assignmentIds = inferences[_inferenceId].assignments;
        uint256 len = assignmentIds.length;
        bool isMatchMinerResult = assignments[assignmentIds[0]].digest ==
            mostVotedDigest;

        //EAI
        uint256 feeForMiner = 0;
        uint256 shareFeePerValidator = 0;
        uint256 remainValue = inferences[_inferenceId].value;

        // Calculate fee for miner and share fee for validators
        if (isMatchMinerResult) {
            //if miner result is correct, then fee for miner = feeRatioMinerValidator * remainValue / 10000
            feeForMiner =
                (remainValue * feeRatioMinerValidator) /
                PERCENTAGE_DENOMINATOR;
            shareFeePerValidator = (remainValue - feeForMiner) / (maxCount - 1);
        } else {
            //if miner result is incorrect, then fee for miner = 0 and all honest validators will share the remainValue
            shareFeePerValidator = remainValue / maxCount;
        }

        bytes memory output;
        for (uint256 i = 0; i < len; i++) {
            Assignment storage assignment = assignments[assignmentIds[i]];
            // Logically, when a worker calls the commit function, it proves that the worker is active.
            // Calling the reveal function is a natural consequence if the worker is honest.
            // Therefore, if a worker calls commit but doesn't call reveal, it is highly likely that they are dishonest,
            // leading to the decision to slash this worker.
            if (assignment.digest != mostVotedDigest) {
                assignment.vote = Vote.Disapproval;
                _slashMiner(assignment.worker, true); // Slash dishonest workers (miner and validators will be slashed in the same way)
            } else {
                if (output.length == 0) {
                    output = assignment.output;
                }

                // process for honest workers
                assignment.vote = Vote.Approval;
                if (assignment.role == AssignmentRole.Validating) {
                    // if it iss validator, then transfer share fee
                    if (shareFeePerValidator > 0) {
                        TransferHelper.safeTransferNative(
                            assignment.worker,
                            shareFeePerValidator
                        );
                    }
                } else {
                    if (feeForMiner > 0) {
                        // it is miner, if miner is honest, the feeForMiner is greater than 0
                        TransferHelper.safeTransferNative(
                            assignment.worker,
                            feeForMiner
                        );
                    }
                }
            }
        }

        // Transfer the mining fee to treasury
        if (inferences[_inferenceId].feeL2 > 0) {
            TransferHelper.safeTransferNative(
                l2Owner,
                inferences[_inferenceId].feeL2
            );
        }
        if (inferences[_inferenceId].feeTreasury > 0) {
            TransferHelper.safeTransferNative(
                treasury,
                inferences[_inferenceId].feeTreasury
            );
        }

        // take result and send it to the callback address
        address desAddr = extendInferInfo[_inferenceId].destination;
        if (desAddr != address(0)) {
            if (desAddr == workHubAddr) {
                _fallBackWorkerHub(
                    extendInferInfo[_inferenceId].inferId,
                    output
                );
            } else {
                _fallBack(extendInferInfo[_inferenceId].destination, output);
            }
        }
        inferences[_inferenceId].status = InferenceStatus.Processed;

        return true;
    }

    function _validatateSolution(bytes calldata _data) internal pure override {
        // Assuming the result contains a single uint8 value
        require(_data.length == 1, "Invalid result length");

        uint8 resultValue = uint8(_data[0]);
        require(
            resultValue >= 1 && resultValue <= 10,
            "Result must be between 1 and 10"
        );
    }

    function resultReceived(
        uint _originInferId,
        bytes calldata _result
    ) external override {
        revert("Not implemented");
    }
}

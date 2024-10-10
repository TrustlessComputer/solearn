// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WorkerHub} from "./WorkerHub.sol";
import {Set} from "./lib/Set.sol";

interface ICallBack {
    function resultReceived(bytes calldata result) external;
    function resultReceived(uint originInferId, bytes calldata result) external;
}

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
    function setupScoringVar(address payable _workhubAddr) onlyOwner external {
        workHubAddr = _workhubAddr;
    }

    function inferWithCallback(
        uint originInferId,
        bytes calldata _input,
        address _creator,
        address callback
    )  external payable returns(uint256 inferid) {
       inferid = WorkerHub(payable(address(this))).infer{value: msg.value}(_input, _creator);

       extendInferInfo[inferid] = InferExtended(msg.sender, callback, originInferId);
    }

    function _fallBackWorkerHub(uint originInferId, bytes memory data) internal {
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
    function _filterCommitment(uint256 _inferenceId) internal override returns (bool) {
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


        // todo: do something

        // take result and send it to the callback address
        // 
        address desAddr = extendInferInfo[_inferenceId].destination;
        if (desAddr != address(0)) {
            if (desAddr == workHubAddr) {
                _fallBackWorkerHub(extendInferInfo[_inferenceId].inferId, bytes(""));
            } else {
                _fallBack(extendInferInfo[_inferenceId].destination, bytes(""));
            }
        }
    }

}


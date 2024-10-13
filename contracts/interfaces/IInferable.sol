// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IInferable {
    function infer(
        bytes calldata data,
        address creator
    ) external payable returns (uint256 inferenceId);

    function inferWithCallback(
        uint originInferId,
        bytes calldata _input,
        address _creator,
        address callback
    ) external payable returns (uint256 inferenceId);
}

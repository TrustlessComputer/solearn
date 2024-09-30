// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IInferable {
    function infer(
        bytes calldata data,
        address creator,
        address referrer
    ) external payable returns (uint256 inferenceId);
}

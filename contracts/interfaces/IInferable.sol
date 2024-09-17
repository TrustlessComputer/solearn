// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IInferable {
    function infer(bytes calldata data, address creator, uint256 cost) external returns (uint256 inferenceId);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IPromptable {
    function prompt(
        bytes calldata data,
        address creator
    ) external payable returns (uint256 promptId);

    function prompt(
        bytes calldata data,
        address creator,
        bool flag
    ) external payable returns (uint256 promptId);
}

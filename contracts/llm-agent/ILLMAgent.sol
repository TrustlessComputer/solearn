// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ICommonAgent} from "../interfaces/ICommonAgent.sol";

interface ILLMAgent is ICommonAgent {
    event PromptPerformed(
        bytes32 indexed uuid,
        uint256 indexed inferId,
        address indexed caller,
        bytes executionData
    );

    function prompt(bytes memory request) external payable returns (uint256);
    function prompt(
        bytes32 uuid,
        bytes memory request
    ) external payable returns (uint256 inferId);

    function getResultById(bytes32 uuid) external view returns (bytes memory);
    function getResultById(
        uint256 promptId
    ) external view returns (bytes memory);
}

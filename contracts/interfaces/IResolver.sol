// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IResolver {
    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes memory a
    ) external;

    function setName(
        bytes32 node,
        string calldata newName
    ) external;

    function addr(bytes32 node) external view returns (address payable);
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IHeapComparator {
    function compareUint256(uint256 a, uint256 b, int64 identifier) external view returns (bool);

    function compareAddress(address a, address b, int64 identifier) external view returns (bool);
}

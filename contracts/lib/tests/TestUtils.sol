// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import { sd } from "@prb/math/src/SD59x18.sol";

import { Utils } from "../Utils.sol";

contract TestUtils {
    function fixedPointToFloatPoint(int256 x) external pure returns (bytes8) {
        return Utils.fixedPointToFloatPoint(sd(x));
    }
}

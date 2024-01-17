// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Tensors.sol";

library Tensor1DMethods {
	function zerosTensor(uint n) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = n;
		ts.mat = new SD59x18[](n);
	}

	function emptyTensor(uint n) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = n;
	}

	function count(Tensors.Tensor1D memory ts) internal pure returns (uint) {
		return ts.n;
	}

	function loadPartial(Tensors.Tensor1D storage ts, SD59x18[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint n = ts.n; 
		while (idx < data.length && ptr < n) {
			ts.mat.push(data[idx]);
			ptr++;
			idx++;
		}
		return (ptr, idx);
	}
}

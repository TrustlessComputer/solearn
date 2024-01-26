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
	
	function from(SD59x18[] memory mat) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = mat.length;
		ts.mat = mat;
	}

	function count(Tensors.Tensor1D memory ts) internal pure returns (uint) {
		return ts.n;
	}
	
	function __apply_unary_op(
		Tensors.Tensor1D memory a,
		function(SD59x18) internal pure returns (SD59x18) op
	) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < res.n; i++) {
			res.mat[i] = op(a.mat[i]);
		}
		return res;
	}

	function __apply_binary_op(
		Tensors.Tensor1D memory a, 
		Tensors.Tensor1D memory b, 
		function(SD59x18, SD59x18) internal pure returns (SD59x18) op
	) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < res.n; i++) {
			res.mat[i] = op(a.mat[i], b.mat[i]);
		}
		return res;
	}
    
	function activation(Tensors.Tensor1D memory a, Tensors.ActivationFunc actv) internal pure returns (Tensors.Tensor1D memory) {
		if (actv == Tensors.ActivationFunc.LeakyReLU) {
			return __apply_unary_op(a, Tensors.__leaky_relu);
		} else if (actv == Tensors.ActivationFunc.Linear) {
			return __apply_unary_op(a, Tensors.__linear);
		} else if (actv == Tensors.ActivationFunc.ReLU) {
			return __apply_unary_op(a, Tensors.__relu);
		} else if (actv == Tensors.ActivationFunc.Sigmoid) {
			return __apply_unary_op(a, Tensors.__sigmoid);
		} else if (actv == Tensors.ActivationFunc.Tanh) {
			return __apply_unary_op(a, Tensors.__tanh);
		} else {
			revert InvalidActivationFunction();
		}
	}
	
	function add(Tensors.Tensor1D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor1D memory) {
		return __apply_binary_op(a, b, Tensors.__add);
	}

	function matMul(Tensors.Tensor1D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(b.m);
		for (uint j = 0; j < b.m; j++) {
			for (uint k = 0; k < b.n; k++) {
				res.mat[j] = res.mat[j] + a.mat[k] * b.mat[k][j];
			}
		}
		return res;
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

	function softmax(Tensors.Tensor1D memory a) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = __apply_unary_op(a, Tensors.__exp);
		SD59x18 sum_e = sd(0);
		for (uint i = 0; i < res.n; i++) {
			sum_e = sum_e + res.mat[i];
		}
		for (uint i = 0; i < a.n; i++) {
			res.mat[i] = res.mat[i].div(sum_e);
		}
		return res;
	}
}

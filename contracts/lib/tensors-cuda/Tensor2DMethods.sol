// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Float64x64 } from "./../Float64x64/Lib.sol";
import "./Tensors.sol";
import "./Tensor1DMethods.sol";
import "../libCuda.sol";

library Tensor2DMethods {
	function zerosTensor(uint n, uint m) internal pure returns (Tensors.Tensor2D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.mat = new Float64x64[][](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new Float64x64[](m);
		}
	}
	
	function emptyTensor(uint n, uint m) internal pure returns (Tensors.Tensor2D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.mat = new Float64x64[][](n);
	}
	
	function from(Float64x64[][] memory mat) internal pure returns (Tensors.Tensor2D memory ts) {
		ts.n = mat.length;
		ts.m = mat[0].length;
		ts.mat = mat;
	}

	function flat(Tensors.Tensor2D memory ts) internal pure returns (Tensors.Tensor1D memory) {
		return Tensor1DMethods.from(flat(ts.mat));
	}

	function flat(Float64x64[][] memory mat) internal pure returns (Float64x64[] memory) {
		Float64x64[] memory result = new Float64x64[](mat.length * mat[0].length);
		uint ptr = 0;
		for (uint i = 0; i < mat.length; i++) {
			for (uint j = 0; j < mat[i].length; j++) {
				result[ptr] = mat[i][j];
				ptr += 1;
			}
		}
		return result;
	}

	function load(Tensors.Tensor2D memory ts, Float64x64[] memory data, uint n, uint m) internal pure {
		ts.n = n;
		ts.m = m;
		ts.mat = new Float64x64[][](n);

		uint ptr = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new Float64x64[](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = ptr < data.length ? data[ptr] : Float64x64.wrap(0);
				ptr += 1;
			}
		}
	}

	function count(Tensors.Tensor2D memory ts) internal pure returns (uint) {
		return ts.n * ts.m;
	}

	function loadPartial(Tensors.Tensor2D storage ts, Float64x64[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint m = ts.m;
		uint cnt = count(ts);
		while (idx < data.length && ptr < cnt) {
			ts.mat[ptr / m].push(data[idx]);
			ptr++;
			idx++;
		}
		return (ptr, idx);
	}

	function cloneTensor(Tensors.Tensor2D memory ts) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory result;
		load(result, flat(ts.mat), ts.n, ts.m);
		return result;
	}

	function __apply_unary_op(
		Tensors.Tensor2D memory a,
		function(Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = zerosTensor(a.n, a.m);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(a.mat[i][j]);
			}
		}
		return res;
	}

	function activation(Tensors.Tensor2D memory a, Tensors.ActivationFunc actv) internal pure returns (Tensors.Tensor2D memory) {
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

	function __apply_binary_op(
		Tensors.Tensor2D memory a, 
		Tensors.Tensor1D memory b, 
		function(Float64x64, Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = zerosTensor(a.n, a.m);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(a.mat[i][j], b.mat[j]);
			}
		}
		return res;
	}

	function __apply_binary_op(
		Tensors.Tensor2D memory a, 
		Tensors.Tensor2D memory b, 
		function(Float64x64, Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = zerosTensor(a.n, a.m);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(a.mat[i][j], b.mat[i % b.n][j % b.m]);
			}
		}
		return res;
	}

	function mul(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor2D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}
	
	function mul(Tensors.Tensor2D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor2D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}

	function add(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor2D memory) {
		return __apply_binary_op(a, b, Tensors.__add);
	}

	function add(Tensors.Tensor2D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor2D memory) {
		return __apply_binary_op(a, b, Tensors.__add);
	}

	function matMul(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res;
		res.n = a.n;
		res.m = b.m;

		res.mat = CUDA.gemmSD59x18(a.mat,b.mat,6,32,32);

		return res;
	}

	function softmax(Tensors.Tensor2D memory a) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = __apply_unary_op(a, Tensors.__exp);
		Float64x64 sum_e = Float64x64.wrap(0);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				sum_e = sum_e + res.mat[i][j];
			}
		}
		for (uint i = 0; i < a.n; i++) {
			for (uint j = 0; j < a.m; j++) {
				res.mat[i][j] = res.mat[i][j].div(sum_e);
			}
		}
		return res;
	}
}

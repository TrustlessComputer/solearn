// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Float32x32 } from "./../Float32x32/Lib32x32.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "./Tensors.sol";
import "../libCuda.sol";

error InvalidMatrixDimensions();

library Tensor1DMethods {
	event TestMatMul(Float32x32[][] data);
	function zerosTensor(uint n) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = n;
		ts.mat = new Float32x32[](n);
	}

	function emptyTensor(uint n) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = n;
	}
	
	function from(Float32x32[] memory mat) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = mat.length;
		ts.mat = mat;
	}

	function count(Tensors.Tensor1D memory ts) internal pure returns (uint) {
		return ts.n;
	}
	
	function __apply_unary_op(
		Tensors.Tensor1D memory a,
		function(Float32x32) internal view returns (Float32x32) op
	) internal view returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < res.n; i++) {
			res.mat[i] = op(a.mat[i]);
		}
		return res;
	}

	function __apply_binary_op(
		Tensors.Tensor1D memory a,
		Tensors.Tensor1D memory b,
		function(Float32x32, Float32x32) internal pure returns (Float32x32) op
	) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < res.n; i++) {
			res.mat[i] = op(a.mat[i], b.mat[i]);
		}
		return res;
	}
    
	function activation(Tensors.Tensor1D memory a, Tensors.ActivationFunc actv) internal view returns (Tensors.Tensor1D memory) {
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

	function add(Tensors.Tensor1D memory a, Float32x32 num) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < a.n; i++) {
			res.mat[i] = a.mat[i] + num;
		}
		return res;
	}


	function mul(Tensors.Tensor1D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor1D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}

	function mul(Tensors.Tensor1D memory a, Float32x32 num) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory res = zerosTensor(a.n);
		for (uint i = 0; i < a.n; i++) {
			res.mat[i] = a.mat[i] * num;
		}
		return res;
	}



	function matMul(Tensors.Tensor1D memory a, Tensors.Tensor2D memory b) internal returns (Tensors.Tensor1D memory) {
		Float32x32[][] memory a_mat = new Float32x32[][](1);
		a_mat[0] = a.mat;
		Float32x32[][] memory res = CUDA.gemmSD59x18(a_mat,b.mat,7,32,32);
		return from(res[0]);
	}

	function load(Tensors.Tensor1D memory ts, Float32x32[] memory data, uint n) internal pure {
		ts.n = n;
		ts.mat = new Float32x32[](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = data[i];
		}
	}

	function matMul(Tensors.Tensor1D memory a, Tensors.Tensor1D memory b) internal view returns (Tensors.Tensor1D memory) {
		if (a.n != b.n) {
			revert InvalidMatrixDimensions();
		}

		Tensors.Tensor1D memory res = zerosTensor(1);
		for (uint i = 0; i < a.n; i++) {
			res.mat[0] = res.mat[0] + a.mat[i] * b.mat[i];
		}
		return res;
	}


	function loadPartial(Tensors.Tensor1D storage ts, Float32x32[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint n = ts.n;
		while (idx < data.length && ptr < n) {
			ts.mat.push(data[idx]);
			ptr++;
			idx++;
		}
		return (ptr, idx);
	}

	function cloneTensor(Tensors.Tensor1D memory ts) internal pure returns (Tensors.Tensor1D memory) {
		Tensors.Tensor1D memory result;
		load(result, ts.mat, ts.n);
		return result;
	}

	function softmax(Tensors.Tensor1D memory a) internal view returns (Tensors.Tensor1D memory) {
		uint n = a.n;

		SD59x18[] memory tmp = new SD59x18[](n);
		for(uint i = 0; i < n; i++) {
			tmp[i] = sd(int(Float32x32.unwrap(a.mat[i])) * 1e18 >> 32);
		}
		// Exp will fail if input is greater than 21
		for(uint i = 0; i < n; i++) {
			tmp[i] = tmp[i].exp();	
		}

		SD59x18 sum_e = sd(0);
		for(uint i = 0; i < n; i++) {
			sum_e = sum_e + tmp[i];
		}
		for(uint i = 0; i < n; i++) {
			tmp[i] = tmp[i].div(sum_e);
		}

		Tensors.Tensor1D memory res = Tensor1DMethods.zerosTensor(n);
		for(uint i = 0; i < n; i++) {
			res.mat[i] = Float32x32.wrap(int64((tmp[i].unwrap() << 32) / 1e18));
		}
		return res;
	}
}

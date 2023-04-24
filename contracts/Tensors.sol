// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

interface IActivation {
	function activation(SD59x18[] memory x) external view returns (SD59x18[] memory);
}

library Tensors {
	struct Tensor {
		SD59x18[][] mat;
		uint n;
		uint m;
	}
	
	enum Activation {
		Linear,
		ReLU,
		LeakyReLU,
		Tanh,
		Sigmoid
	}

	function from(Tensor memory ts, SD59x18[][] memory mat) internal pure returns (Tensor memory) {
		ts.n = mat.length;
		ts.m = mat[0].length;
		ts.mat = mat;
		return ts;
	}


	function flat(SD59x18[][] memory mat) internal pure returns (SD59x18[] memory) {
		SD59x18[] memory result = new SD59x18[](mat.length * mat[0].length);
		uint p = 0;
		for (uint i = 0; i < mat.length; i++) {
			for (uint j = 0; j < mat[i].length; j++) {
				result[p] = mat[i][j];
				p += 1;
			}
		}
		return result;
	}

	function load(Tensor memory ts, SD59x18[] memory data, uint n, uint m) internal pure {
		ts.n = n;
		ts.m = m;
		ts.mat = new SD59x18[][](n);

		uint p = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = p < data.length ? data[p] : sd(0);
				p += 1;
			}
		}
	}

	function cloneTensor(Tensor memory ts) internal pure returns (Tensor memory) {
		Tensor memory result;
		load(result, flat(ts.mat), ts.n, ts.m);
		return result;
	}

	function __linear(SD59x18 x) internal pure returns (SD59x18) {
		return x;
	}

	function __relu(SD59x18 x) internal pure returns (SD59x18) {
		return x.unwrap() > 0 ? x : sd(0);
	}

	function __leaky_relu(SD59x18 x) internal pure returns (SD59x18) {
		return x.unwrap() > 0 ? x : x.mul(sd(2e18)).div(sd(10e18));
	}

	function __sigmoid(SD59x18 x) internal pure returns (SD59x18) {
		return sd(1e18).div(sd(1e18) + sd(-x.unwrap()).exp());
	}

	function __tanh(SD59x18 x) internal pure returns (SD59x18) {
		SD59x18 t = sd(2e18).mul(x).exp();
		return (t - sd(1e18)).div(t + sd(1e18));
	}

	function __apply_unary_op(
		Tensor memory a,
		function(SD59x18) internal pure returns (SD59x18) op
	) internal pure returns (Tensor memory) {
		Tensor memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j]);
			}
		}
		return res;
	}

	function linear(Tensor memory a) internal pure returns (Tensor memory) {
		return __apply_unary_op(a, __linear);
	}

	function relu(Tensor memory a) internal pure returns (Tensor memory) {
		return __apply_unary_op(a, __relu);
	}

	function leaky_relu(Tensor memory a) internal pure returns (Tensor memory) {
		return __apply_unary_op(a, __leaky_relu);
	}

	function sigmoid(Tensor memory a) internal pure returns (Tensor memory) {
		return __apply_unary_op(a, __sigmoid);
	}

	function tanh(Tensor memory a) internal pure returns (Tensor memory) {
		return __apply_unary_op(a, __tanh);
	}

	function __add(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a + b;
	}

	function __mul(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a * b;
	}

	function __exp(SD59x18 a) internal pure returns (SD59x18) {
		return a.exp();
	}

    function __apply_binary_op(Tensor memory a, Tensor memory b, function(SD59x18, SD59x18) internal pure returns (SD59x18) op) internal pure returns (Tensor memory) {
		if (b.n == 0) {
			b.n = 1;
			b.m = 1;
			b.mat = new SD59x18[][](1);
		}

		Tensor memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j], b.mat[i % b.n][j % b.m]);
			}
		}
		return res;
	}


    function mul(Tensor memory a, Tensor memory b) internal pure returns (Tensor memory) {
		return __apply_binary_op(a, b, __mul);
	}
    function add(Tensor memory a, Tensor memory b) internal pure returns (Tensor memory) {
    	return __apply_binary_op(a, b, __add);
    }

    function matMul(Tensor memory a, Tensor memory b) internal pure returns (Tensor memory) {
    	Tensor memory res;
    	res.n = a.n;
    	res.m = b.m;
    	res.mat = new SD59x18[][](res.n);

    	for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < a.m; k++) {
					res.mat[i][j] = res.mat[i][j] + a.mat[i][k].mul(b.mat[k][j]);
				}
			}
		}
		return res;
	}

    function softmax(Tensor memory a) internal pure returns (Tensor memory) {
		Tensor memory res = __apply_unary_op(a, __exp);
		SD59x18 sum_e = sd(0);
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


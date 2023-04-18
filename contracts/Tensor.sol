// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "solmate/src/utils/FixedPointMathLib.sol";

contract Tensor {
	struct TensorData {
		uint[][] mat;
		uint n;
		uint m;
	}

	function flat(uint[][] memory mat) internal pure returns (uint[] memory) {
		uint[] memory result = new uint[](mat.length * mat[0].length);
		uint p = 0;
		for (uint i = 0; i < mat.length; i++) {
			for (uint j = 0; j < mat[i].length; j++) {
				result[p] = mat[i][j];
				p += 1;
			}
		}
		return result;
	}


	function loadm(TensorData memory ts, uint[] memory data, uint n, uint m) public {
		ts.n = n;
		ts.m = m;
		ts.mat = new uint[][](n);

		uint p = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new uint[](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = p < data.length ? data[p] : 0;
				p += 1;
			}
		}

	}

	// function load(TensorData memory ts, uint[] memory data, uint n, uint m) public {
	// 	ts.n = n;
	// 	ts.m = m;
	// 	ts.mat = new uint[][](n);

	// 	uint p = 0;
	// 	for (uint i = 0; i < n; i++) {
	// 		ts.mat[i] = new uint[](m);
	// 		for (uint j = 0; j < m; j++) {
	// 			ts.mat[i][j] = p < data.length ? data[p] : 0;
	// 			p += 1;
	// 		}
	// 	}
	// }

	function cloneTensor(TensorData memory ts) public view returns (TensorData memory) {
		TensorData memory result;
		loadm(result, flat(ts.mat), ts.n, ts.m);
		return result;
	}

	function __linear(uint x) internal pure returns (uint) {
		return x;
	}

	function __relu(uint x) internal pure returns (uint) {
		return x > 0 ? x : 0;
	}

	function __leaky_relu(uint x) internal pure returns (uint) {
		return x > 0 ? x : x * 2 / 10;
	}

	function __sigmoid(uint x) internal pure returns (uint) {
		return 1 / (1 + 2**(-x));
	}

	function __tanh(uint x) internal pure returns (uint) {
		return (2 / (1 + 2**(-2 * x))) - 1;
	}

	function __apply_unary_op(
		TensorData memory a,
		function(uint) internal pure returns (uint) op
	) internal pure returns (TensorData memory) {
		TensorData memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j]);
			}
		}
		return res;
	}

	function linear(TensorData memory a) public pure returns (TensorData memory) {
		return __apply_unary_op(a, __linear);
	}

	function relu(TensorData memory a) public pure returns (TensorData memory) {
		return __apply_unary_op(a, __relu);
	}

	function leaky_relu(TensorData memory a) public pure returns (TensorData memory) {
		return __apply_unary_op(a, __leaky_relu);
	}

	function sigmoid(TensorData memory a) public pure returns (TensorData memory) {
		return __apply_unary_op(a, __sigmoid);
	}

	function tanh(TensorData memory a) public pure returns (TensorData memory) {
		return __apply_unary_op(a, __tanh);
	}

	function __add(uint a, uint b) internal pure returns (uint) {
		return a + b;
	}

	function __mul(uint a, uint b) internal pure returns (uint) {
		return a * b;
	}

	function __exp(uint a, uint b) internal pure returns (uint) {
		return FixedPointMathLib.rpow(a, b, FixedPointMathLib.WAD);
	}

    function __apply_binary_op(TensorData memory a, TensorData memory b, function(uint, uint) internal pure returns (uint) op) internal pure returns (uint) {
		if (b.n == 0) {
			b.n = 1;
			b.m = 1;
			b.mat = new uint[][](1);
		}

		TensorData memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j], b.mat[i % b.n][j % b.m]);
			}
		}
		return res;
	}


    function mul(TensorData memory a, TensorData memory b) public pure returns (TensorData memory) {
		return __apply_binary_op(a, b, __mul);
	}
    function add(TensorData memory a, TensorData memory b) public pure returns (TensorData memory) {
    	return __apply_binary_op(a, b, __add);
    }

    function matMul(TensorData memory a, TensorData memory b) public pure returns (TensorData memory) {
    	TensorData memory res = new TensorData([], a.n, b.m);
    	for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < a.m; k++) {
					res.mat[i][j] += a.mat[i][k] * b.mat[k][j];
				}
			}
		}
		return res;
	}

    function softmax(TensorData memory a) public pure returns (TensorData memory) {
		TensorData memory res = __apply_unary_op(a, __exp);
		uint sum_e = 0;
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				sum_e += res.mat[i][j];
			}
		}
		for (uint i = 0; i < a.n; i++) {
			for (uint j = 0; j < a.m; j++) {
				res.mat[i][j] /= sum_e;
			}
		}
		return res;
	}
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "solmate/src/utils/FixedPointMathLib.sol";
import { SD59x18, sd, unwrap, wrap, abs, avg, mul, div, sqrt, powu, pow, exp, log2} from "@prb/math/src/SD59x18.sol";

contract Tensor {
	SD59x18 constant ONE = sd(1e18);
	SD59x18 constant TWO = sd(2e18);
	SD59x18 constant E = sd(2.718281828459045235e18);

	struct TensorData {
		SD59x18[][] mat;
		uint n;
		uint m;
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


	function loadm(TensorData memory ts, SD59x18[] memory data, uint n, uint m) public {
		ts.n = n;
		ts.m = m;
		ts.mat = new SD59x18[][](n);

		uint p = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = p < data.length ? data[p] : 0;
				p += 1;
			}
		}

	}

	// function load(TensorData memory ts, uint[] memory data, uint n, uint m) public {
	// 	ts.n = n;
	// 	ts.m = m;
	// 	ts.mat = new SD59x18[][](n);

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

	function __linear(SD59x18 x) internal pure returns (SD59x18) {
		return x;
	}

	function __relu(SD59x18 x) internal pure returns (SD59x18) {
		return x > 0 ? x : 0;
	}

	function __leaky_relu(SD59x18 x) internal pure returns (SD59x18) {
		return x > 0 ? x : x * sd(0.2e18);
	}

	function __sigmoid(SD59x18 x) internal pure returns (SD59x18) {
		return ONE / (ONE + pow(E, -x));
	}

	function __tanh(SD59x18 x) internal pure returns (SD59x18) {
		SD59x18 t = pow(E, TWO * x);
		return (t - 1)/(t + 1);
	}

	function __apply_unary_op(
		TensorData memory a,
		function(SD59x18) internal pure returns (SD59x18) op
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

	function __add(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a + b;
	}

	function __mul(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a * b;
	}

	function __exp(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return pow(a, b);
	}

    function __apply_binary_op(TensorData memory a, TensorData memory b, function(uint, uint) internal pure returns (uint) op) internal pure returns (uint) {
		if (b.n == 0) {
			b.n = 1;
			b.m = 1;
			b.mat = new SD59x18[][](1);
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
		SD59x18 sum_e = 0;
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


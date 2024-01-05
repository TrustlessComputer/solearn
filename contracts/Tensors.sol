// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

error InvalidActivationFunction();
error InvalidPaddingType();

library Tensors {
	struct Tensor2D {
		SD59x18[][] mat;
		uint n;
		uint m;
	}

	struct Tensor4D {
		SD59x18[][][][] mat;
		uint n;
		uint m;
		uint p;
		uint q;
	}

	enum ActivationFunc {
		LeakyReLU,
		Linear,
		ReLU,
		Sigmoid,
		Tanh
	}

	enum PaddingType {
		Valid,
		Same
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

	function __add(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a + b;
	}

	function __mul(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a.mul(b);
	}

	function __exp(SD59x18 a) internal pure returns (SD59x18) {
		return a.exp();
	}
	
	function max(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a.unwrap() > b.unwrap() ? a : b;
	}

	function getConvSize(
		uint w, 
		uint h, 
		uint f_w, 
		uint f_h, 
		uint s_w,
		uint s_h, 
		PaddingType padding
	) internal pure returns (
		uint W,
		uint H,
		uint L,
		uint T
	) {
		W = 0; 
		H = 0; 
		L = 0; 
		T = 0; 		
		if (padding == PaddingType.Same) {
			W = (w + s_w - 1) / s_w;
			H = (h + s_h - 1) / s_h;
			uint pad_w = (w % s_w == 0) ? Math.max(f_w - s_w, 0) : Math.max(f_w - w % s_w, 0);
			uint pad_h = (h % s_h == 0) ? Math.max(f_h - s_h, 0) : Math.max(f_h - h % s_h, 0);
			L = pad_w / 2;
			T = pad_h / 2;
		} else if (padding == PaddingType.Valid) {
			W = (w - f_w) / s_w + 1;
			H = (h - f_h) / s_h + 1;
		} else {
			revert InvalidPaddingType();
		}
	}
}

library Tensor2DMethods {
	function from(Tensors.Tensor2D memory ts, SD59x18[][] memory mat) internal pure returns (Tensors.Tensor2D memory) {
		ts.n = mat.length;
		ts.m = mat[0].length;
		ts.mat = mat;
		return ts;
	}

	function flat(SD59x18[][] memory mat) internal pure returns (SD59x18[] memory) {
		SD59x18[] memory result = new SD59x18[](mat.length * mat[0].length);
		uint ptr = 0;
		for (uint i = 0; i < mat.length; i++) {
			for (uint j = 0; j < mat[i].length; j++) {
				result[ptr] = mat[i][j];
				ptr += 1;
			}
		}
		return result;
	}

	function load(Tensors.Tensor2D memory ts, SD59x18[] memory data, uint n, uint m) internal pure {
		ts.n = n;
		ts.m = m;
		ts.mat = new SD59x18[][](n);

		uint ptr = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = ptr < data.length ? data[ptr] : sd(0);
				ptr += 1;
			}
		}
	}

	function cloneTensor(Tensors.Tensor2D memory ts) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory result;
		load(result, flat(ts.mat), ts.n, ts.m);
		return result;
	}

	function __apply_unary_op(
		Tensors.Tensor2D memory a,
		function(SD59x18) internal pure returns (SD59x18) op
	) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j]);
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

    function __apply_binary_op(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b, function(SD59x18, SD59x18) internal pure returns (SD59x18) op) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				res.mat[i][j] = op(res.mat[i][j], b.mat[i % b.n][j % b.m]);
			}
		}
		return res;
	}

    function mul(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor2D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}
	
    function add(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor2D memory) {
    	return __apply_binary_op(a, b, Tensors.__add);
    }

    function matMul(Tensors.Tensor2D memory a, Tensors.Tensor2D memory b) internal pure returns (Tensors.Tensor2D memory) {
    	Tensors.Tensor2D memory res;
    	res.n = a.n;
    	res.m = b.m;
    	res.mat = new SD59x18[][](res.n);

    	for (uint i = 0; i < res.n; i++) {
    		res.mat[i] = new SD59x18[](res.m);
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < a.m; k++) {
					res.mat[i][j] = res.mat[i][j] + a.mat[i][k].mul(b.mat[k][j]);
				}
			}
		}
		return res;
	}

    function softmax(Tensors.Tensor2D memory a) internal pure returns (Tensors.Tensor2D memory) {
		Tensors.Tensor2D memory res = __apply_unary_op(a, Tensors.__exp);
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

library Tensor4DMethods {
	function from(Tensors.Tensor4D memory ts, SD59x18[][][][] memory mat) internal pure returns (Tensors.Tensor4D memory) {
		ts.n = mat.length;
		ts.m = mat[0].length;
		ts.p = mat[0][0].length;
		ts.q = mat[0][0][0].length;
		ts.mat = mat;
		return ts;
	}

	function flat(SD59x18[][][][] memory mat) internal pure returns (SD59x18[] memory) {
		uint n = mat.length;
		uint m = mat[0].length;
		uint p = mat[0][0].length;
		uint q = mat[0][0][0].length;
		SD59x18[] memory result = new SD59x18[](n * m * p * q);
		uint ptr = 0;
		for (uint i = 0; i < n; i++) {
			for (uint j = 0; j < m; j++) {
				for (uint k = 0; k < p; k++) {
					for (uint l = 0; l < q; l++) {
						result[ptr] = mat[i][j][k][l];
						ptr += 1;
					}
				}
			}
		}
		return result;
	}

	function load(Tensors.Tensor4D memory ts, SD59x18[] memory data, uint n, uint m, uint p, uint q) internal pure {
		ts.n = n;
		ts.m = m;
		ts.p = p;
		ts.q = q;
		ts.mat = new SD59x18[][][][](n);

		uint ptr = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[][][](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = new SD59x18[][](p);
				for (uint k = 0; j < p; k++) {
					ts.mat[i][j][k] = new SD59x18[](q);
					for (uint l = 0; l < q; l++) {
						ts.mat[i][j][k][l] = ptr < data.length ? data[ptr] : sd(0);
						ptr += 1;
					}
				}
			}
		}
	}

	function flatKeep1stDim(Tensors.Tensor4D memory ts) internal pure returns (Tensors.Tensor2D memory res) {
		Tensor2DMethods.load(res, flat(ts.mat), ts.n, ts.m * ts.p * ts.q);
	}

	function cloneTensor(Tensors.Tensor4D memory ts) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory result;
		load(result, flat(ts.mat), ts.n, ts.m, ts.p, ts.q);
		return result;
	}

	function __apply_unary_op(
		Tensors.Tensor4D memory a,
		function(SD59x18) internal pure returns (SD59x18) op
	) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						res.mat[i][j][k][l] = op(res.mat[i][j][k][l]);
					}
				}
			}
		}
		return res;
	}

	function activation(Tensors.Tensor4D memory a, Tensors.ActivationFunc actv) internal pure returns (Tensors.Tensor4D memory) {
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

    function __apply_binary_op(Tensors.Tensor4D memory a, Tensors.Tensor4D memory b, function(SD59x18, SD59x18) internal pure returns (SD59x18) op) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = cloneTensor(a);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						res.mat[i][j][k][l] = op(res.mat[i][j][k][l], b.mat[i % b.n][j % b.m][k % b.p][l % b.q]);
					}
				}
			}
		}
		return res;
	}

    function mul(Tensors.Tensor4D memory a, Tensors.Tensor4D memory b) internal pure returns (Tensors.Tensor4D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}
	
    function add(Tensors.Tensor4D memory a, Tensors.Tensor4D memory b) internal pure returns (Tensors.Tensor4D memory) {
    	return __apply_binary_op(a, b, Tensors.__add);
    }

	// Input: (N, W, H, D)
	function maxPooling2D(
		Tensors.Tensor4D memory a,
		uint[2] memory size,
		uint[2] memory stride,
		Tensors.PaddingType padding
	) internal pure returns (Tensors.Tensor4D memory) {
		uint n = a.n; uint w = a.m; uint h = a.p; uint d = a.q;
		(uint f_w, uint f_h) = (size[0], size[1]);
		(uint s_w, uint s_h) = (stride[0], stride[1]);
		
		(uint W, uint H, uint L, uint T) = Tensors.getConvSize(w, h, f_w, f_h, s_w, s_h, padding);

		SD59x18[] memory data;
		Tensors.Tensor4D memory res;
		load(res, data, n, W, H, d);
		for(uint i = 0; i < n; ++i) {
			for(uint x = 0; x < W; ++x) {
				for(uint y = 0; y < H; ++y) {
					for(uint p = 0; p < d; ++p) {            
						SD59x18 cell = sd(-1e9 * 1e18);
						for(uint dx = 0; dx < f_w; ++dx) {
							for(uint dy = 0; dy < f_h; ++dy) {
								uint X = x*s_w + dx - L;
								uint Y = y*s_h + dy - T;
								bool isIn = (X >= 0 && X < w && Y >= 0 && Y < h);
								SD59x18 val = isIn ? a.mat[i][X][Y][p] : sd(0);
								cell = Tensors.max(cell, val);
							}
						}
						res.mat[i][x][y][p] = cell;
					}
				}
			}
		}

		return res;
	}

	// Input: (N, W, H, D)
	// Filter: (F_W, F_H, D, K)
	function conv2D(
		Tensors.Tensor4D memory a,
		Tensors.Tensor4D memory b,
		uint[2] memory stride,
		Tensors.PaddingType padding
	) internal pure returns (Tensors.Tensor4D memory) {
		uint n = a.n; uint w = a.m; uint h = a.p; uint d = a.q;
		uint f_w = b.n; uint f_h = b.m; uint k = b.q;
		(uint s_w, uint s_h) = (stride[0], stride[1]);
		
		(uint W, uint H, uint L, uint T) = Tensors.getConvSize(w, h, f_w, f_h, s_w, s_h, padding);

		SD59x18[] memory data;
		Tensors.Tensor4D memory res;
		load(res, data, n, W, H, k);
		for(uint i = 0; i < n; ++i) {
			for(uint x = 0; x < W; ++x) {
				for(uint y = 0; y < H; ++y) {
					for(uint p = 0; p < k; ++p) {            
						SD59x18 cell = sd(0);
						for(uint dx = 0; dx < f_w; ++dx) {
							for(uint dy = 0; dy < f_h; ++dy) {
								uint X = x*s_w + dx - L;
								uint Y = y*s_h + dy - T;
								bool isIn = (X >= 0 && X < w && Y >= 0 && Y < h);
								for(uint q = 0; q < d; ++q) {
									SD59x18 val = isIn ? a.mat[i][X][Y][q] : sd(0);
									cell = cell + val * b.mat[dx][dy][q][p];
								}
							}
						}
						res.mat[i][x][y][p] = cell;
					}
				}
			}
		}

		return res;
	}

    function softmax(Tensors.Tensor4D memory a) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = __apply_unary_op(a, Tensors.__exp);
		SD59x18 sum_e = sd(0);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						sum_e = sum_e + res.mat[i][j][k][l];
					}
				}
			}
		}
		for (uint i = 0; i < a.n; i++) {
			for (uint j = 0; j < a.m; j++) {
				for (uint k = 0; k < a.p; k++) {
					for (uint l = 0; l < a.q; l++) {
						res.mat[i][j][k][l] = res.mat[i][j][k][l].div(sum_e);
					}
				}
			}
		}
		return res;
	}
}

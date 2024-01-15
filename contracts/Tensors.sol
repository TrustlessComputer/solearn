// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

error InvalidActivationFunction();
error InvalidPaddingType();

library Tensors {
	struct Tensor1D {
		SD59x18[] mat;
		uint n;
	}

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
	
	function __subMax0(uint a, uint b) public pure returns (uint) {
		return a > b ? a - b : 0;
	}

	function max(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a.unwrap() > b.unwrap() ? a : b;
	}

	function getConvSize(
		uint[2] memory dim,
		uint[2] memory size,
		uint[2] memory stride,
		PaddingType padding
	) internal pure returns (
		uint[2] memory out,
		uint[2] memory pad
	) {
		for(uint i = 0; i < 2; ++i) {
			if (padding == PaddingType.Same) {
				out[i] = (dim[i] + stride[i] - 1) / stride[i];
				uint total_pad = (dim[i] % stride[i] == 0) ? __subMax0(size[i], stride[i]) : __subMax0(size[i], dim[i] % stride[i]);
				pad[i] = total_pad / 2;
			} else if (padding == PaddingType.Valid) {
				// TODO: What if dim[i] < size[i]
				out[i] = (dim[i] - size[i]) / stride[i] + 1;
			} else {
				revert InvalidPaddingType();
			}
		}
	}
}

library Tensor1DMethods {
	function emptyTensor(uint n) internal pure returns (Tensors.Tensor1D memory ts) {
		ts.n = n;
		ts.mat = new SD59x18[](n);
	}

	function count(Tensors.Tensor1D memory ts) internal pure returns (uint) {
		return ts.n;
	}

	function loadPartial(Tensors.Tensor1D storage ts, SD59x18[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint n = ts.n; 
		while (idx < data.length && ptr < n) {
			ts.mat[ptr] = data[idx];
			ptr++;
			idx++;
		}
		return (ptr, idx);
	}
}

library Tensor2DMethods {
	function emptyTensor(uint n, uint m) internal pure returns (Tensors.Tensor2D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.mat = new SD59x18[][](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[](m);
		}
	}
	
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

	function count(Tensors.Tensor2D memory ts) internal pure returns (uint) {
		return ts.n * ts.m;
	}

	function loadPartial(Tensors.Tensor2D storage ts, SD59x18[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint n = ts.n; 
		uint m = ts.m;
		while (idx < data.length && ptr < n * m) {
			ts.mat[ptr / m][ptr % m] = data[idx];
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
	function emptyTensor(uint n, uint m, uint p, uint q) internal pure returns (Tensors.Tensor4D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.p = p;
		ts.q = q;
		ts.mat = new SD59x18[][][][](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new SD59x18[][][](m);
			for(uint j = 0; j < m; j++) {
				ts.mat[i][j] = new SD59x18[][](p);
				for(uint k = 0; k < p; k++) {
					ts.mat[i][j][k] = new SD59x18[](q);
				}
			}
		}
	}
	
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
				for (uint k = 0; k < p; k++) {
					ts.mat[i][j][k] = new SD59x18[](q);
					for (uint l = 0; l < q; l++) {
						ts.mat[i][j][k][l] = ptr < data.length ? data[ptr] : sd(0);
						ptr += 1;
					}
				}
			}
		}
	}

	function count(Tensors.Tensor4D memory ts) internal pure returns (uint) {
		return ts.n * ts.m * ts.p * ts.q;
	}

	function loadPartial(Tensors.Tensor4D storage ts, SD59x18[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint n = ts.n; 
		uint m = ts.m;
		uint p = ts.p;
		uint q = ts.q;
		while (idx < data.length && ptr < n * m * p * q) {
			ts.mat[ptr / (m * p * q)][ptr / (p * q) % m][ptr / q % p][ptr % q] = data[idx];
			ptr++;
			idx++;
		}
		return (ptr, idx);
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

	function __cell_max(
		Tensors.Tensor4D memory a,
		uint[2] memory pos,
		uint[2] memory size,
		uint i,
		uint p
	) internal pure returns (SD59x18) {
		unchecked {
		SD59x18 cell = sd(-1e9 * 1e18);
		for(uint dx = 0; dx < size[0]; ++dx) {
			for(uint dy = 0; dy < size[1]; ++dy) {
				uint X = pos[0] + dx;
				uint Y = pos[1] + dy;
				SD59x18 val = (X >= 0 && X < a.m && Y >= 0 && Y < a.p) ? a.mat[i][X][Y][p] : sd(0);
				cell = Tensors.max(cell, val);
			}
		}
		return cell;
		}
	}

	function __cell_conv(
		Tensors.Tensor4D memory a,
		Tensors.Tensor4D memory b,
		uint[2] memory pos,
		uint[2] memory size,
		uint i,
		uint p
	) internal pure returns (SD59x18) {
		unchecked {
		SD59x18 cell = sd(0);
		for(uint dx = 0; dx < size[0]; ++dx) {
			for(uint dy = 0; dy < size[1]; ++dy) {
				uint X = pos[0] + dx;
				uint Y = pos[1] + dy;
				if (X >= 0 && X < a.m && Y >= 0 && Y < a.p) {
					for(uint q = 0; q < a.q; ++q) {
						cell = cell + a.mat[i][X][Y][q] * b.mat[dx][dy][q][p];
					}
				}
			}
		}
		return cell;
		}
	}

	// Input: (N, W, H, D)
	function maxPooling2D(
		Tensors.Tensor4D memory a,
		uint[2] memory size,
		uint[2] memory stride,
		Tensors.PaddingType padding
	) internal pure returns (Tensors.Tensor4D memory) {
		unchecked {
		(uint[2] memory dim, uint[2] memory pad) = Tensors.getConvSize([a.m, a.p], size, stride, padding);

		Tensors.Tensor4D memory res = Tensor4DMethods.emptyTensor(a.n, dim[0], dim[1], a.q);
		for(uint i = 0; i < a.n; ++i) {
			for(uint x = 0; x < dim[0]; ++x) {
				for(uint y = 0; y < dim[1]; ++y) {
					uint[2] memory pos = [x*stride[0] - pad[0], y*stride[1] - pad[1]];
					for(uint p = 0; p < a.q; ++p) {
						res.mat[i][x][y][p] = __cell_max(a, pos, size, i, p);
					}
				}
			}
		}

		return res;
		}
	}

	// Input: (N, W, H, D)
	// Filter: (F_W, F_H, D, K)
	function conv2D(
		Tensors.Tensor4D memory a,
		Tensors.Tensor4D memory b,
		uint[2] memory stride,
		Tensors.PaddingType padding
	) internal pure returns (Tensors.Tensor4D memory) {
		unchecked {
		uint[2] memory size = [b.n, b.m];
		(uint[2] memory dim, uint[2] memory pad) = Tensors.getConvSize([a.m, a.p], size, stride, padding);

		Tensors.Tensor4D memory res = Tensor4DMethods.emptyTensor(a.n, dim[0], dim[1], b.q);
		for(uint i = 0; i < a.n; ++i) {
			for(uint x = 0; x < dim[0]; ++x) {
				for(uint y = 0; y < dim[1]; ++y) {
					uint[2] memory pos = [x*stride[0] - pad[0], y*stride[1] - pad[1]];
					for(uint p = 0; p < b.q; ++p) {
						res.mat[i][x][y][p] = __cell_conv(a, b, pos, size, i, p);
					}
				}
			}
		}

		return res;			
		}
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

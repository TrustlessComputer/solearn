// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Float64x64, fromInt } from "./../Float64x64/Lib.sol";
import "./Tensors.sol";
import "./Tensor2DMethods.sol";

library Tensor4DMethods {
	function zerosTensor(uint n, uint m, uint p, uint q) internal pure returns (Tensors.Tensor4D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.p = p;
		ts.q = q;
		ts.mat = new Float64x64[][][][](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new Float64x64[][][](m);
			for(uint j = 0; j < m; j++) {
				ts.mat[i][j] = new Float64x64[][](p);
				for(uint k = 0; k < p; k++) {
					ts.mat[i][j][k] = new Float64x64[](q);
				}
			}
		}
	}

	function emptyTensor(uint n, uint m, uint p, uint q) internal pure returns (Tensors.Tensor4D memory ts) {
		ts.n = n;
		ts.m = m;
		ts.p = p;
		ts.q = q;
		ts.mat = new Float64x64[][][][](n);
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new Float64x64[][][](m);
			for(uint j = 0; j < m; j++) {
				ts.mat[i][j] = new Float64x64[][](p);
			}
		}
	}

	function from(Float64x64[][][][] memory mat) internal pure returns (Tensors.Tensor4D memory ts) {
		ts.n = mat.length;
		ts.m = mat[0].length;
		ts.p = mat[0][0].length;
		ts.q = mat[0][0][0].length;
		ts.mat = mat;
	}

	function flat(Float64x64[][][][] memory mat) internal pure returns (Float64x64[] memory) {
		uint n = mat.length;
		uint m = mat[0].length;
		uint p = mat[0][0].length;
		uint q = mat[0][0][0].length;
		Float64x64[] memory result = new Float64x64[](n * m * p * q);
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

	function load(Tensors.Tensor4D memory ts, Float64x64[] memory data, uint n, uint m, uint p, uint q) internal pure {
		ts.n = n;
		ts.m = m;
		ts.p = p;
		ts.q = q;
		ts.mat = new Float64x64[][][][](n);

		uint ptr = 0;
		for (uint i = 0; i < n; i++) {
			ts.mat[i] = new Float64x64[][][](m);
			for (uint j = 0; j < m; j++) {
				ts.mat[i][j] = new Float64x64[][](p);
				for (uint k = 0; k < p; k++) {
					ts.mat[i][j][k] = new Float64x64[](q);
					for (uint l = 0; l < q; l++) {
						ts.mat[i][j][k][l] = ptr < data.length ? data[ptr] : Float64x64.wrap(0);
						ptr += 1;
					}
				}
			}
		}
	}

	function count(Tensors.Tensor4D memory ts) internal pure returns (uint) {
		return ts.n * ts.m * ts.p * ts.q;
	}

	function loadPartial(Tensors.Tensor4D storage ts, Float64x64[] memory data, uint ptr, uint idx) internal returns (uint, uint) {
		uint m = ts.m;
		uint p = ts.p;
		uint q = ts.q;
		uint cnt = count(ts);
		while (idx < data.length && ptr < cnt) {
			ts.mat[ptr / (m * p * q)][ptr / (p * q) % m][ptr / q % p].push(data[idx]);
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
		function(Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = zerosTensor(a.n, a.m, a.p, a.q);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						res.mat[i][j][k][l] = op(a.mat[i][j][k][l]);
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

	function __apply_binary_op(
		Tensors.Tensor4D memory a,
		Tensors.Tensor1D memory b,
		function(Float64x64, Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = zerosTensor(a.n, a.m, a.p, a.q);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						res.mat[i][j][k][l] = op(a.mat[i][j][k][l], b.mat[l]);
					}
				}
			}
		}
		return res;
	}

	function __apply_binary_op(
		Tensors.Tensor4D memory a,
		Tensors.Tensor4D memory b,
		function(Float64x64, Float64x64) internal pure returns (Float64x64) op
	) internal pure returns (Tensors.Tensor4D memory) {
		Tensors.Tensor4D memory res = zerosTensor(a.n, a.m, a.p, a.q);
		for (uint i = 0; i < res.n; i++) {
			for (uint j = 0; j < res.m; j++) {
				for (uint k = 0; k < res.p; k++) {
					for (uint l = 0; l < res.q; l++) {
						res.mat[i][j][k][l] = op(a.mat[i][j][k][l], b.mat[i % b.n][j % b.m][k % b.p][l % b.q]);
					}
				}
			}
		}
		return res;
	}

	function mul(Tensors.Tensor4D memory a, Tensors.Tensor4D memory b) internal pure returns (Tensors.Tensor4D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}
	
	function mul(Tensors.Tensor4D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor4D memory) {
		return __apply_binary_op(a, b, Tensors.__mul);
	}
	
	function add(Tensors.Tensor4D memory a, Tensors.Tensor4D memory b) internal pure returns (Tensors.Tensor4D memory) {
		return __apply_binary_op(a, b, Tensors.__add);
	}

	function add(Tensors.Tensor4D memory a, Tensors.Tensor1D memory b) internal pure returns (Tensors.Tensor4D memory) {
		return __apply_binary_op(a, b, Tensors.__add);
	}

	function __cell_max(
		Tensors.Tensor4D memory a,
		uint[2] memory pos,
		uint[2] memory size,
		uint i,
		uint p
	) internal pure returns (Float64x64) {
		unchecked {
		Float64x64 cell = fromInt(-1e9);
		for(uint dx = 0; dx < size[0]; ++dx) {
			for(uint dy = 0; dy < size[1]; ++dy) {
				uint X = pos[0] + dx;
				uint Y = pos[1] + dy;
				Float64x64 val = (X >= 0 && X < a.m && Y >= 0 && Y < a.p) ? a.mat[i][X][Y][p] : Float64x64.wrap(0);
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
	) internal pure returns (Float64x64) {
		unchecked {
		Float64x64 cell = Float64x64.wrap(0);
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

		Tensors.Tensor4D memory res = Tensor4DMethods.zerosTensor(a.n, dim[0], dim[1], a.q);
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

		Tensors.Tensor4D memory res = Tensor4DMethods.zerosTensor(a.n, dim[0], dim[1], b.q);
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
		Float64x64 sum_e = Float64x64.wrap(0);
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

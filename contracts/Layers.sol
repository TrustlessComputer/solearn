// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Tensors.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

import "hardhat/console.sol";

error TooMuchData();

library Layers {
	using Tensor1DMethods for Tensors.Tensor1D;
	using Tensor2DMethods for Tensors.Tensor2D;
	using Tensor4DMethods for Tensors.Tensor4D;

	struct RescaleLayer {
		uint layerIndex; // index within the model
		SD59x18 scale;
		SD59x18 offset;
	}

	struct FlattenLayer {
		uint layerIndex;
	}

	struct DenseLayer {
		uint layerIndex;
		Tensors.ActivationFunc activation;
		uint out_dim;
		Tensors.Tensor2D w;
		Tensors.Tensor1D b;
		uint ptrLayer;
		uint ptr;
	}

	struct MaxPooling2DLayer {
		uint layerIndex;
		uint[2] size;
		uint[2] stride;
		Tensors.PaddingType padding;
	}

	struct Conv2DLayer {
		uint layerIndex;
		Tensors.ActivationFunc activation;
		uint filters;
		uint[2] stride;
		Tensors.PaddingType padding;
		Tensors.Tensor4D w;
		Tensors.Tensor1D b;
		uint ptrLayer;
		uint ptr;
	}

	function forward(FlattenLayer memory layer, SD59x18[][][][] memory mat) internal pure returns (SD59x18[][] memory) {
		Tensors.Tensor4D memory xt;
		xt.from(mat);
		Tensors.Tensor2D memory yt = Tensor4DMethods.flatKeep1stDim(xt);
		return yt.mat;
	}

	function forward(RescaleLayer memory layer, SD59x18[][][][] memory x) internal pure returns (SD59x18[][][][] memory) {
		uint n = x.length;
		uint m = x[0].length;
		uint p = x[0][0].length;
		uint q = x[0][0][0].length;

		SD59x18[][][][] memory y = new SD59x18[][][][](n);
		for (uint i = 0; i < n; i++) {
			y[i] = new SD59x18[][][](m);
			for (uint j = 0; j < m; j++) {
				y[i][j] = new SD59x18[][](p);
				for (uint k = 0; k < p; k++) {
					y[i][j][k] = new SD59x18[](q);
					for (uint l = 0; l < q; l++) {
						y[i][j][k][l] = x[i][j][k][l].mul(layer.scale) + layer.offset;
					}
				}
			}
		}
		return y;
	}

	function forward(DenseLayer memory layer, SD59x18[][] memory x) internal pure returns (SD59x18[][] memory) {
		Tensors.Tensor2D memory xt;
		xt.from(x);
		Tensors.Tensor2D memory wt;
		wt = layer.w;
		Tensors.Tensor2D memory bt;
		bt.load(layer.b.mat, 1, layer.b.n);
		Tensors.Tensor2D memory y = xt.matMul(wt).add(bt);
		Tensors.Tensor2D memory zt = y.activation(layer.activation);
		return zt.mat;
	}

	function forward(MaxPooling2DLayer memory layer, SD59x18[][][][] memory x) internal pure returns (SD59x18[][][][] memory) {
		Tensors.Tensor4D memory xt;
		xt.from(x);
		Tensors.Tensor4D memory yt = xt.maxPooling2D(layer.stride, layer.size, layer.padding);
		return yt.mat;
	}

	function forward(Conv2DLayer memory layer, SD59x18[][][][] memory x) internal pure returns (SD59x18[][][][] memory) {
		Tensors.Tensor4D memory xt;
		xt.from(x);
		Tensors.Tensor4D memory wt;
		wt = layer.w;
		Tensors.Tensor4D memory bt;
		bt.load(layer.b.mat, 1, 1, 1, layer.b.n);
		Tensors.Tensor4D memory yt = xt.conv2D(wt, layer.stride, layer.padding).add(bt);
		Tensors.Tensor4D memory zt = yt.activation(layer.activation);
		return zt.mat;
	}

	function appendWeights(DenseLayer storage layer, SD59x18[] memory x) internal {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			(ptr, idx) = layer.w.loadPartial(x, ptr, idx);
			if (ptr == layer.w.size()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 1) {
			(ptr, idx) = layer.b.loadPartial(x, ptr, idx);
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
	}

	function appendWeights(Conv2DLayer storage layer, SD59x18[] memory x) internal {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			(ptr, idx) = layer.w.loadPartial(x, ptr, idx);
			if (ptr == layer.w.size()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 1) {
			(ptr, idx) = layer.b.loadPartial(x, ptr, idx);
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
	}
}

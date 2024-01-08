// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Tensors.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

library Layers {
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
		SD59x18[][] w;
		SD59x18[] b;
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
		SD59x18[][][][] w;
		SD59x18[] b;
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
					for (uint l = 0; l < p; l++) {
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
		wt.from(layer.w);
		Tensors.Tensor2D memory bt;
		bt.load(layer.b, 1, layer.b.length);
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
		wt.from(layer.w);
		Tensors.Tensor4D memory bt;
		bt.load(layer.b, 1, 1, 1, layer.b.length);
		Tensors.Tensor4D memory yt = xt.conv2D(wt, layer.stride, layer.padding).add(bt);
		Tensors.Tensor4D memory zt = yt.activation(layer.activation);
		return zt.mat;
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Tensors.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

library Layers {
	using Tensors for Tensors.Tensor2D;

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

	function forward(FlattenLayer memory layer, SD59x18[][] memory mat) internal pure returns (SD59x18[][] memory) {
		SD59x18[][] memory result = new SD59x18[][](1);
		result[0] = Tensors.flat(mat);
		return result;
	}

	function forward(RescaleLayer memory layer, SD59x18[][] memory x) internal pure returns (SD59x18[][] memory) {
		SD59x18[][] memory y = new SD59x18[][](x.length);
		for (uint i = 0; i < x.length; i++) {
			y[i] = new SD59x18[](x[0].length);
			for (uint j = 0; j < x[0].length; j++) {
				y[i][j] = x[i][j].mul(layer.scale) + layer.offset;
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

}

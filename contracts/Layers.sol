// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Tensors.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

error InvalidActivationFunction();

library Layers {
	using Tensors for Tensors.Tensor;
	enum ActivationFunc {
		LeakyReLU,
		Linear,
		ReLU,
		Sigmoid,
		Tanh
	}

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
		ActivationFunc activation;
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

	function activation(DenseLayer memory layer, Tensors.Tensor memory x) internal pure returns (Tensors.Tensor memory) {
		ActivationFunc actv = layer.activation;
		if (actv == ActivationFunc.LeakyReLU) {
			return x.cloneTensor().leaky_relu();
		} else if (actv == ActivationFunc.Linear) {
			return x.cloneTensor().linear();
		} else if (actv == ActivationFunc.ReLU) {
			return x.cloneTensor().relu();
		} else if (actv == ActivationFunc.Sigmoid) {
			return x.cloneTensor().sigmoid();
		} else if (actv == ActivationFunc.Tanh) {
			return x.cloneTensor().tanh();
		} else {
			revert InvalidActivationFunction();
		}
	}

	function forward(DenseLayer memory layer, SD59x18[][] memory x) internal pure returns (SD59x18[][] memory) {
		Tensors.Tensor memory xt;
		xt.from(x);
		Tensors.Tensor memory wt;
		wt.from(layer.w);
		Tensors.Tensor memory bt;
		bt.load(layer.b, 1, layer.b.length);
		Tensors.Tensor memory y = xt.matMul(wt).add(bt);
		Tensors.Tensor memory zt = activation(layer, y);
		return zt.mat;
	}

}

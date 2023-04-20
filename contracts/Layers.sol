// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Utils.sol";
import "./Tensors.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

interface IActivation {
	function activation(SD59x18[] memory x) external view returns (SD59x18[] memory);
}


library Layers {
	struct RescaleLayer {
		SD59x18 scale;
		SD59x18 offset;
	}

	struct FlattenLayer {
		bytes32 temp;
	}

	struct DenseLayer {
		uint out_dim;
		SD59x18[][] w;
		SD59x18[] b;
	}

	function forward(FlattenLayer memory layer, SD59x18[][] memory mat) internal view returns (SD59x18[] memory) {
		return Tensors.flat(mat);
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

	function forward(DenseLayer memory layer, SD59x18[][] memory x, IActivation actv) internal view returns (SD59x18[][] memory) {
		Tensors.Tensor memory xt;
		Tensors.from(xt, x);
		Tensors.Tensor memory wt;
		Tensors.from(wt, layer.w);
		Tensors.Tensor memory bt;
		Tensors.load(bt, layer.b, 1, layer.b.length);
		Tensors.Tensor memory y = Tensors.add(Tensors.matMul(xt, wt), bt);
		SD59x18[] memory z = actv.activation(Tensors.flat(y.mat));
		Tensors.Tensor memory zt;
		Tensors.load(zt, z, y.mat.length, y.mat[0].length);
		return zt.mat;
	}
}

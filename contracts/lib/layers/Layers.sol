// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../tensors/Tensors.sol";
import "../tensors/Tensor1DMethods.sol";
import "../tensors/Tensor2DMethods.sol";
import "../tensors/Tensor3DMethods.sol";
import "../tensors/Tensor4DMethods.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

import "hardhat/console.sol";

error TooMuchData();

library Layers {
	using Tensor1DMethods for Tensors.Tensor1D;
	using Tensor2DMethods for Tensors.Tensor2D;
	using Tensor3DMethods for Tensors.Tensor3D;
	using Tensor4DMethods for Tensors.Tensor4D;

	struct SingleLayerConfig {
		bytes conf;
		uint256 ind;
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

	struct EmbeddingLayer {
		uint layerIndex;
		uint inputDim;
		uint outputDim;
		Tensors.Tensor2D w;
		uint ptrLayer;
		uint ptr;
	}

	struct SimpleRNNLayer {
		uint layerIndex;
		uint units;
		Tensors.ActivationFunc activation;
		Tensors.Tensor2D wx;
		Tensors.Tensor2D wh;
		Tensors.Tensor1D b;
		uint ptrLayer;
		uint ptr;
	}

	function forward(FlattenLayer memory layer, SD59x18[][][] memory mat) internal pure returns (SD59x18[] memory) {
		Tensors.Tensor3D memory xt = Tensor3DMethods.from(mat);
		return Tensor3DMethods.flat(xt.mat);
	}

	function forward(RescaleLayer memory layer, SD59x18[][][] memory x) internal pure returns (SD59x18[][][] memory) {
		uint n = x.length;
		uint m = x[0].length;
		uint p = x[0][0].length;

		SD59x18[][][] memory y = new SD59x18[][][](n);
		for (uint i = 0; i < n; i++) {
			y[i] = new SD59x18[][](m);
			for (uint j = 0; j < m; j++) {
				y[i][j] = new SD59x18[](p);
				for (uint k = 0; k < p; k++) {
					y[i][j][k] = x[i][j][k].mul(layer.scale) + layer.offset;					
				}
			}
		}
		return y;
	}

	function forward(DenseLayer memory layer, SD59x18[] memory x) internal pure returns (SD59x18[] memory) {
		Tensors.Tensor1D memory xt = Tensor1DMethods.from(x);
		Tensors.Tensor2D memory wt = layer.w;
		Tensors.Tensor1D memory bt = layer.b;
		Tensors.Tensor1D memory y = xt.matMul(wt).add(bt);
		Tensors.Tensor1D memory zt = y.activation(layer.activation);
		return zt.mat;
	}

	function forward(MaxPooling2DLayer memory layer, SD59x18[][][] memory x) internal pure returns (SD59x18[][][] memory) {
		Tensors.Tensor3D memory xt = Tensor3DMethods.from(x);
		Tensors.Tensor3D memory yt = xt.maxPooling2D(layer.stride, layer.size, layer.padding);
		return yt.mat;
	}

	function forward(Conv2DLayer memory layer, SD59x18[][][] memory x) internal pure returns (SD59x18[][][] memory) {
		Tensors.Tensor3D memory xt = Tensor3DMethods.from(x);
		Tensors.Tensor4D memory wt = layer.w;
		Tensors.Tensor1D memory bt = layer.b;
		Tensors.Tensor3D memory yt = xt.conv2D(wt, layer.stride, layer.padding).add(bt);
		Tensors.Tensor3D memory zt = yt.activation(layer.activation);
		return zt.mat;
	}

	function forward(EmbeddingLayer memory layer, uint x) internal pure returns (SD59x18[] memory) {
		return layer.w.mat[x];
	}

	function forward(SimpleRNNLayer memory layer, SD59x18[] memory x, SD59x18[] memory states) internal pure returns (SD59x18[] memory) {
		Tensors.Tensor1D memory x_t = Tensor1DMethods.from(x);
		Tensors.Tensor1D memory h_t = Tensor1DMethods.from(states);
		Tensors.Tensor1D memory yx_t = Tensor1DMethods.matMul(x_t, layer.wx);
		Tensors.Tensor1D memory yh_t = Tensor1DMethods.matMul(h_t, layer.wh);
		Tensors.Tensor1D memory y_t = Tensor1DMethods.add(Tensor1DMethods.add(yx_t, yh_t), layer.b);
		Tensors.Tensor1D memory z_t = Tensor1DMethods.activation(y_t, layer.activation);
		return z_t.mat;
	}

	function appendWeights(DenseLayer storage layer, SD59x18[] memory x) internal returns (uint) {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			uint m = layer.w.m;
			uint cnt = layer.w.n * layer.w.m;
			while (idx < x.length && ptr < cnt) {
				layer.w.mat[ptr / m].push(x[idx]);
				ptr++;
				idx++;
			}
			if (ptr == cnt) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 1) {
			uint n = layer.b.n; 
			while (idx < x.length && ptr < n) {
				layer.b.mat.push(x[idx]);
				ptr++;
				idx++;
			}
			if (ptr == n) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
		return idx;
	}

	function appendWeights(Conv2DLayer storage layer, SD59x18[] memory x) internal returns (uint) {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			(ptr, idx) = layer.w.loadPartial(x, ptr, idx);
			if (ptr == layer.w.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 1) {
			(ptr, idx) = layer.b.loadPartial(x, ptr, idx);
			if (ptr == layer.b.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
		return idx;
	}

	function appendWeights(EmbeddingLayer storage layer, SD59x18[] memory x) internal returns (uint) {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			(ptr, idx) = layer.w.loadPartial(x, ptr, idx);
			if (ptr == layer.w.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
		return idx;
	}

	function appendWeights(SimpleRNNLayer storage layer, SD59x18[] memory x) internal returns (uint) {
		uint ptrLayer = layer.ptrLayer;
		uint ptr = layer.ptr;
		uint idx = 0;
		if (ptrLayer == 0) {
			(ptr, idx) = layer.wx.loadPartial(x, ptr, idx);
			if (ptr == layer.wx.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 1) {
			(ptr, idx) = layer.wh.loadPartial(x, ptr, idx);
			if (ptr == layer.wh.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (ptrLayer == 2) {
			(ptr, idx) = layer.b.loadPartial(x, ptr, idx);
			if (ptr == layer.b.count()) {
				++ptrLayer;
				ptr = 0;
			}
		}
		if (idx < x.length) {
			revert TooMuchData();
		}
		layer.ptrLayer = ptrLayer;
		layer.ptr = ptr;
		return idx;
	}

	function makeDenseLayer(SingleLayerConfig memory slc, uint256 dim) internal pure returns (DenseLayer memory layer, uint256 out_dim, uint256 requiredWeights) {
		(, uint8 actv, uint256 d) = abi.decode(
			slc.conf,
			(uint8, uint8, uint256)
		);
		layer = Layers.DenseLayer(
			slc.ind,
			Tensors.ActivationFunc(actv),
			d,
			Tensor2DMethods.emptyTensor(dim, d),
			Tensor1DMethods.emptyTensor(d),
			0,
			0
		);
		out_dim = d;
		requiredWeights = layer.w.count() + layer.b.count();
	}

	function makeFlattenLayer(SingleLayerConfig memory slc, uint256[3] memory dim) internal pure returns (FlattenLayer memory layer, uint256 out_dim) {
		layer = FlattenLayer(slc.ind);
		out_dim = dim[0] * dim[1] * dim[2];
	}

	function makeRescaleLayer(SingleLayerConfig memory slc) internal pure returns (RescaleLayer memory layer) {
		(, SD59x18 scale, SD59x18 offset) = abi.decode(
			slc.conf,
			(uint8, SD59x18, SD59x18)
		);
		layer = RescaleLayer(
			slc.ind,
			scale,
			offset
		);
	}

	function makeMaxPooling2DLayer(SingleLayerConfig memory slc, uint256[3] memory dim) internal pure returns (MaxPooling2DLayer memory layer, uint256[3] memory out_dim) {
		(, uint256[2] memory size, uint256[2] memory stride, uint8 padding) = abi.decode(
			slc.conf,
			(uint8, uint256[2], uint256[2], uint8)
		);
		layer = Layers.MaxPooling2DLayer(
			slc.ind,
			size,
			stride,
			Tensors.PaddingType(padding)
		);
 		uint256[2] memory out;
    (out, ) = Tensors.getConvSize(
			[dim[0], dim[1]],
			size,
			stride,
			Tensors.PaddingType(padding)
		);
		out_dim = [out[0], out[1], dim[2]];
	}

	function makeConv2DLayer(SingleLayerConfig memory slc, uint256[3] memory dim) internal pure returns (Conv2DLayer memory layer, uint256[3] memory out_dim, uint256 requiredWeights) {
		(, uint8 actv, uint256 filters, uint256[2] memory size, uint256[2] memory stride, uint8 padding) = abi.decode(
				slc.conf,
				(uint8, uint8, uint256, uint256[2], uint256[2], uint8)
		);
		layer = Layers.Conv2DLayer(
			slc.ind,
			Tensors.ActivationFunc(actv),
			filters,
			stride,
			Tensors.PaddingType(padding),
			Tensor4DMethods.emptyTensor(size[0], size[1], dim[2], filters),
			Tensor1DMethods.emptyTensor(filters),
			0,
			0
		);

		uint256[2] memory out;
		(out, ) = Tensors.getConvSize(
			[dim[0], dim[1]],
			size,
			stride,
			Tensors.PaddingType(padding)
		);
		out_dim = [out[0], out[1], filters];
		requiredWeights = layer.w.count() + layer.b.count();
	}

	function makeEmbeddingLayer(SingleLayerConfig memory slc) internal pure returns (EmbeddingLayer memory layer, uint256 out_dim, uint256 requiredWeights) {
		(, uint256 inputDim, uint256 outputDim) = abi.decode(
			slc.conf,
			(uint8, uint256, uint256)
		);
		layer = Layers.EmbeddingLayer(
			slc.ind,
			inputDim,
			outputDim,
			Tensor2DMethods.emptyTensor(inputDim, outputDim),
			0,
			0
		);
		out_dim = outputDim;
		requiredWeights = layer.w.count();
	}

	function makeSimpleRNNLayer(SingleLayerConfig memory slc, uint256 dim) internal pure returns (SimpleRNNLayer memory layer, uint256 out_dim, uint256 requiredWeights) {
		(, uint8 actv, uint256 units) = abi.decode(
			slc.conf,
			(uint8, uint8, uint256)
		);
		layer = Layers.SimpleRNNLayer(
			slc.ind,
			units,
			Tensors.ActivationFunc(actv),
			Tensor2DMethods.emptyTensor(dim, units),
			Tensor2DMethods.emptyTensor(units, units),
			Tensor1DMethods.emptyTensor(units),
			0,
			0
		);
		out_dim = units;
		requiredWeights = layer.wx.count() + layer.wh.count() + layer.b.count();
	}
}

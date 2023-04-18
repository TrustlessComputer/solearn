// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Utils.sol";
import "./Tensors.sol";
import "./Layers.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract MultilayerPerceptron {
	using Layers for Layers.RescaleLayer;
	using Layers for Layers.FlattenLayer;
	using Layers for Layers.DenseLayer;
	using Tensors for Tensors.Tensor;

	Layers.RescaleLayer[] preprocessLayers;
	Layers.DenseLayer[] hiddenLayers;
	Layers.DenseLayer outputLayer;

	constructor(Layers.RescaleLayer[] memory _preprocessLayers, Layers.DenseLayer[] memory _hiddenLayers, Layers.DenseLayer memory _outputLayer) {
		for (uint i = 0; i < _preprocessLayers.length; i++) {
			preprocessLayers.push(_preprocessLayers[i]);
		}
		for (uint i = 0; i < _hiddenLayers.length; i++) {
			hiddenLayers.push(_hiddenLayers[i]);
		}
		outputLayer = _outputLayer;
	}

	function getInfo() public view returns (uint[] memory, SD59x18[][][] memory) {
		uint[] memory out_dim = new uint[](hiddenLayers.length);
		SD59x18[][][] memory w_b = new SD59x18[][][](hiddenLayers.length);
		for (uint i = 0; i < hiddenLayers.length; i++) {
			out_dim[i] = hiddenLayers[i].out_dim;
			w_b[i] = new SD59x18[][](2);
			w_b[i][0] = Tensors.flat(hiddenLayers[i].w);
			w_b[i][1] = hiddenLayers[i].b;
		}
		return (out_dim, w_b);
	}

	function activation(SD59x18[] memory x) public pure returns (SD59x18[] memory) {
		SD59x18[] memory y = new SD59x18[](x.length);
		for (uint i = 0; i < x.length; i++) {
			y[i] = Tensors.__sigmoid(x[i]);
		}
		return y;
	}

	function forward(SD59x18[][] memory x) public view returns (SD59x18[] memory) {
		for (uint i = 0; i < preprocessLayers.length; i++) {
			x = preprocessLayers[i].forward(x);
		}
		for (uint i = 0; i < hiddenLayers.length; i++) {
			x = hiddenLayers[i].forward(x, IActivation(address(this)));
		}
		x = outputLayer.forward(x, IActivation(address(this)));
		Tensors.Tensor memory xt;
		xt.from(x);
		return Tensors.flat(xt.softmax().mat);
	}
}

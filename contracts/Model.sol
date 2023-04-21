// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Perceptron.sol";
import "./Tensors.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";


contract Model is MultilayerPerceptron {
	using Tensors for Tensors.Tensor;
	uint[3] inputDim;
	string modelName;
	string[] classesName;

	enum LayerType {
		Dense,
		Flatten,
		Rescale
	}

	enum ActivationType {

	}

	constructor(string memory model_name, bytes[] memory layers_config, SD59x18[] memory weights, string[] memory classes_name) {
		uint ipd = loadPerceptron(layers_config, weights);
		inputDim = ipd;
		modelName = model_name;
		
		for (uint i = 0; i < classes_name.length; i++) {
			classesName.push(classes_name[i]);
		}
	}

	function makeLayer(bytes calldata conf, bool isOutput) internal {
		// TODO
		uint8 layerType = uint8(conf[0]);
		if (layerType == uint8(LayerType.Dense)) {
			(uint d, SD59x18[][] memory w, SD59x18[] memory b) = abi.decode(conf[1:], (uint, SD59x18[][], SD59x18[]));
			Layers.DenseLayer memory layer = Layers.DenseLayer(d, w, b);
			if (isOutput) {
				outputLayer = layer;
			} else {
				hiddenLayers.push(layer);
			}
		} else if (layerType == uint8(LayerType.Flatten)) {
			Layers.FlattenLayer memory layer = Layers.FlattenLayer(1);
		} else if (layerType == uint8(LayerType.Rescale)) {
			(SD59x18 scale, SD59x18 offset) = abi.decode(conf[1:], (SD59x18, SD59x18));
			Layers.RescaleLayer memory layer = Layers.RescaleLayer(scale, offset);
			preprocessLayers.push(layer);
		}
	}

	function loadPerceptron(bytes[] memory layers_config, SD59x18[] memory weights) public pure returns (uint) {
		// TODO
		uint[3] memory ipd;
		
		for (uint i = 0; i < layers_config.length; i++) {
			makeLayer(layers_config[i], i + 1 < layers_config.length);
		}

		return ( ipd );
	}

	function getInfo() public virtual view returns (uint, uint[] memory, uint[] memory, uint[] memory, string memory, string[] memory) {
		(uint[] memory hiddenNeurons, uint[] memory activationFunc, uint[][][] memory parameters) = super.getInfo();
		return (inputDim, parameters, hiddenNeurons, activationFunc, modelName, classesName);
	}

	function classifyImage(SD59x18[] memory pixels) public view returns (uint[] memory) {
		Tensors.Tensor memory img_tensor;
		img_tensor.load(pixels, 1, pixels.length);

		Tensors.Tensor memory result_tensor = forward(img_tensor);
		uint[] memory result = result_tensor.mat[0];

		return result;
	}
}

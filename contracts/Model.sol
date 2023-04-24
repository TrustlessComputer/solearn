// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Perceptron.sol";
import "./Tensors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract Model is MultilayerPerceptron, Ownable {
	using Tensors for Tensors.Tensor;
	uint[3] inputDim;
	string modelName;
	string[] classesName;

	enum LayerType {
		Dense,
		Flatten,
		Rescale,
		Input
	}

	constructor(string memory model_name, string[] memory classes_name) MultilayerPerceptron() {
		modelName = model_name;
		
		for (uint i = 0; i < classes_name.length; i++) {
			classesName.push(classes_name[i]);
		}
	}

	function loadWeights(bytes[] memory layers_config, SD59x18[] memory weights) external onlyOwner {
		loadPerceptron(layers_config, weights);		
	}

	function makeLayer(bytes memory conf, bool isOutput, uint ind) internal {
		bytes memory temp = new bytes(1);
		temp[0] = conf[0];
		uint8 layerType = abi.decode(temp, (uint8));
		
		if (layerType == uint8(LayerType.Dense)) {
			(uint8 t1, uint8 actv, uint d, SD59x18[][] memory w, SD59x18[] memory b) = abi.decode(conf, (uint8, uint8, uint, SD59x18[][], SD59x18[]));
			Layers.DenseLayer memory layer = Layers.DenseLayer(ind, Layers.ActivationFunc(actv), d, w, b);
			if (isOutput) {
				outputLayer = layer;
			} else {
				hiddenLayers.push(layer);
			}
		} else if (layerType == uint8(LayerType.Flatten)) {
			// Layers.FlattenLayer memory layer = Layers.FlattenLayer();
		} else if (layerType == uint8(LayerType.Rescale)) {
			(uint8 t1, SD59x18 scale, SD59x18 offset) = abi.decode(conf, (uint8, SD59x18, SD59x18));
			Layers.RescaleLayer memory layer = Layers.RescaleLayer(ind, scale, offset);
			preprocessLayers.push(layer);
		} else if (layerType == uint8(LayerType.Input)) {
			inputDim = abi.decode(conf, (uint8[3]));
		}
	}

	function loadPerceptron(bytes[] memory layersConfig, SD59x18[] memory weights) public {
		// TODO
		for (uint i = 0; i < layersConfig.length; i++) {
			makeLayer(layersConfig[i], i + 1 < layersConfig.length, i);
		}
	}

	function getModelInfo() public view returns (uint[3] memory, SD59x18[][][] memory, uint[] memory, string memory, string[] memory) {
		(uint[] memory hiddenNeurons, SD59x18[][][] memory parameters) = super.getInfo();
		return (inputDim, parameters, hiddenNeurons, modelName, classesName);
	}

	function classifyImage(SD59x18[] memory pixels) public view returns (SD59x18[] memory) {
		Tensors.Tensor memory img_tensor;
		img_tensor.load(pixels, 1, pixels.length);

		SD59x18[] memory result = forward(img_tensor.mat);
		// uint[] memory result = result_tensor.mat[0];

		return result;
	}
}

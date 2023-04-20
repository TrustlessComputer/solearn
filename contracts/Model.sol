// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Perceptron.sol";
import "./Tensors.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract Model is MultilayerPerceptron {
	using Tensors for Tensors.Tensor;
	uint inputDim;
	string modelName;
	string[] classesName;

	enum LayerType {
		Dense,
		Flatten,
		Rescale
	}

	constructor(string memory model_name, bytes[] memory layers_config, SD59x18[] memory weights, string[] memory classes_name) MultilayerPerceptron() {
		uint ipd = loadPerceptron(layers_config, weights);
		inputDim = ipd;
		modelName = model_name;
		
		for (uint i = 0; i < classes_name.length; i++) {
			classesName.push(classes_name[i]);
		}
	}

	function makeLayer(bytes memory conf, bool isOutput) internal {
		bytes memory temp = new bytes(1);
		temp[0] = conf[0];
		uint8 layerType = abi.decode(temp, (uint8));
		
		if (layerType == uint8(LayerType.Dense)) {
			(uint8 t1, uint d, SD59x18[][] memory w, SD59x18[] memory b) = abi.decode(conf, (uint8, uint, SD59x18[][], SD59x18[]));
			Layers.DenseLayer memory layer = Layers.DenseLayer(d, w, b);
			if (isOutput) {
				outputLayer = layer;
			} else {
				hiddenLayers.push(layer);
			}
		} else if (layerType == uint8(LayerType.Flatten)) {
			// Layers.FlattenLayer memory layer = Layers.FlattenLayer();
		} else if (layerType == uint8(LayerType.Rescale)) {
			(uint8 t1, SD59x18 scale, SD59x18 offset) = abi.decode(conf, (uint8, SD59x18, SD59x18));
			Layers.RescaleLayer memory layer = Layers.RescaleLayer(scale, offset);
			preprocessLayers.push(layer);
		}
	}

	function loadPerceptron(bytes[] memory layersConfig, SD59x18[] memory weights) public pure returns (uint) {

		uint dim = 0;
		uint p = 0;
		uint ipd = 0;
		// for (uint i = 0; i < layersConfig.length; i++) {
		// 	if (layersConfig[i] == 0) {
		// 		dim = layersConfig[i + 1];
		// 		ipd = dim;
		// 	} else if (layersConfig[i] == 1) {
		// 		preprocessLayers.push(Layers.RescaleLayer(layersConfig[i + 1], layersConfig[i + 2]));
		// 	} else if (layersConfig[i] == 2) {
		// 		// dim = [dim.reduce((a, b) => a * b)];
		// 		// solidity:
		// 		dim = 1;
		// 		for (uint j = 0; j < layersConfig[i + 1]; j++) {
		// 			dim *= layersConfig[i + 2 + j];
		// 		}
		// 	} else if (layersConfig[i] == 3) {
		// 		uint nxt_dim = [layersConfig[i + 1]];
		// 		uint w_size = dim[0] * nxt_dim[0];
		// 		uint b_size = nxt_dim[0];

				// uint[] memory w_array = weights.subarray(p, p + w_size);
				// p += w_size;
				// uint[] memory b_array = weights.subarray(p, p + b_size);
				// p += b_size;

				// Tensors.Tensor memory w_tensor;
				// w_tensor.load(w_array, dim[0], nxt_dim[0]);
				// Tensors.Tensor memory b_tensor;
				// b_tensor.load(b_array, 1, nxt_dim[0]);

				// hiddenLayers.push(Layers.DenseLayer(nxt_dim[0], w_tensor, b_tensor));
		// 		dim = nxt_dim;
		// 	}
		// }

		// Layers.DenseLayer memory outputLayer = hiddenLayers.pop();

		return ipd;
	}

	function getModelInfo() public view returns (uint, SD59x18[][][] memory, uint[] memory, string memory, string[] memory) {
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

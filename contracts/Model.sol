// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Perceptron.sol";
import "./Tensors.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract Model {
	using Tensors for Tensors.Tensor;
	MultilayerPerceptron perceptron;
	uint inputDim;
	string modelName;
	string[] classesName;

	constructor(bytes memory inscription) {
		(string memory model_name, uint[] memory layers_config, string memory weight_b64, string[] memory classes_name) = abi.decode(inscription, (string, uint[], string, string[]));
		(address perc, uint ipd) = loadPerceptron(layers_config, weight_b64);
		perceptron = MultilayerPerceptron(perc);
		inputDim = ipd;
		modelName = model_name;
		
		for (uint i = 0; i < classes_name.length; i++) {
			classesName.push(classes_name[i]);
		}
	}

	function loadPerceptron(SD59x18[] memory layersConfig, string memory weights_b64) public pure returns (MultilayerPerceptron, uint) {
		// TODO
		Layers.RescaleLayer[] memory preprocessLayers = new Layers.RescaleLayer[](0);
		Layers.DenseLayer[] memory hiddenLayers = new Layers.DenseLayer[](0);

		uint[] memory weights = base64ToFloatArray(weights_b64);

		uint dim = 0;
		uint p = 0;
		uint ipd = 0;
		for (uint i = 0; i < layersConfig.length; i++) {
			if (layersConfig[i] == 0) {
				dim = layersConfig[i + 1];
				ipd = dim;
			} else if (layersConfig[i] == 1) {
				preprocessLayers.push(Layers.RescaleLayer(layersConfig[i + 1], layersConfig[i + 2]));
			} else if (layersConfig[i] == 2) {
				// dim = [dim.reduce((a, b) => a * b)];
				// solidity:
				dim = 1;
				for (uint j = 0; j < layersConfig[i + 1]; j++) {
					dim *= layersConfig[i + 2 + j];
				}
			} else if (layersConfig[i] == 3) {
				uint nxt_dim = [layersConfig[i + 1]];
				uint w_size = dim[0] * nxt_dim[0];
				uint b_size = nxt_dim[0];

				uint[] memory w_array = weights.subarray(p, p + w_size);
				p += w_size;
				uint[] memory b_array = weights.subarray(p, p + b_size);
				p += b_size;

				Tensors.Tensor memory w_tensor;
				w_tensor.load(w_array, dim[0], nxt_dim[0]);
				Tensors.Tensor memory b_tensor;
				b_tensor.load(b_array, 1, nxt_dim[0]);

				// uint activation = getActivationFromName(layersConfig[i + 1]);

				hiddenLayers.push(Layers.DenseLayer(nxt_dim[0], w_tensor, b_tensor));

				dim = nxt_dim;
			}
		}

		Layers.DenseLayer memory outputLayer = hiddenLayers.pop();

		MultilayerPerceptron perc = new MultilayerPerceptron(preprocessLayers, hiddenLayers, outputLayer);
		return ( perceptron, ipd );
	}

	function getInfo() public view returns (uint, uint[] memory, uint[] memory, uint[] memory, string memory, string[] memory) {
		(uint[] memory hiddenNeurons, uint[] memory activationFunc, uint[][][] memory parameters) = perceptron.getInfo();
		return (inputDim, parameters, hiddenNeurons, activationFunc, modelName, classesName);
	}

	function classifyImage(SD59x18[] memory pixels) public view returns (uint[] memory) {
		Tensors.Tensor memory img_tensor;
		img_tensor.load(pixels, 1, pixels.length);

		Tensors.Tensor memory result_tensor = perceptron.forward(img_tensor);
		uint[] memory result = result_tensor.mat[0];

		return result;
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Perceptron.sol";
import "./Tensors.sol";

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract Model {
	using Tensors for Tensors.Tensor;
	MultilayerPerceptron perceptron;
	uint[3] inputDim;
	string modelName;
	string[] classesName;

	struct Config {
		uint layerType;
		int[] data;
	}

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

	function loadPerceptron(Config[] memory layersConfig, SD59x18[] memory weights) public pure returns (MultilayerPerceptron, uint[3] memory) {
		// TODO
		uint dim = 0;
		uint p = 0;
		uint[3] memory ipd;
		
		uint layerType = 0;
		int[] memory data;
		for (uint i = 0; i < layersConfig.length; i++) {
			layerType = layersConfig[i].layerType;
			data = layersConfig[i].data;
			if (layerType == 0) {
				ipd = [uint(data[0]), uint(data[1]), uint(data[2])];
			} else if (layerType == 1) {
				preprocessLayers.push(Layers.RescaleLayer(sd(data[0]), sd(data[1])));
			} else if (layerType == 2) {
				// dim = [dim.reduce((a, b) => a * b)];
				// solidity:
				dim = 1;
				for (uint j = 0; j < 3; j++) {
					dim *= ipd[j];
				}
			} else if (layerType == 3) {
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

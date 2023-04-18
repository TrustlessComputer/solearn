// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Model {
	Perceptron perceptron;
	uint inputDim;
	string modelName;
	string[] classesName;

	constructor(bytes memory inscription) {
		(string memory model_name, uint[] memory layers_config, string memory weight_b64, string[] memory classes_name) = abi.decode(inscription, (string, uint[], string, string[]));
		(Perceptron memory perceptron, uint inputDim) = loadPerceptron(layers_config, weight_b64);
		perceptron = perceptron;
		inputDim = inputDim;
		modelName = model_name;
		classesName = classes_name;
	}

	function loadPerceptron(uint[] memory layersConfig, string memory weights_b64) public pure returns (Perceptron memory, uint) {
		RescaleLayer[] memory preprocessLayers = new RescaleLayer[](0);
		DenseLayer[] memory hiddenLayers = new DenseLayer[](0);

		uint[] memory weights = base64ToFloatArray(weights_b64);

		uint dim = null;
		uint p = 0;
		uint inputDim = 0;
		for (uint i = 0; i < layersConfig.length; i++) {
			if (layersConfig[i] == 0) {
				dim = layersConfig[i + 1];
				inputDim = dim;
			} else if (layersConfig[i] == 1) {
				preprocessLayers.push(new RescaleLayer(layersConfig[i + 1], layersConfig[i + 2]));
			} else if (layersConfig[i] == 2) {
				dim = [dim.reduce((a, b) => a * b)];
			} else if (layersConfig[i] == 3) {
				uint nxt_dim = [layersConfig[i + 1]];
				uint w_size = dim[0] * nxt_dim[0];
				uint b_size = nxt_dim[0];

				uint[] memory w_array = weights.subarray(p, p + w_size);
				p += w_size;
				uint[] memory b_array = weights.subarray(p, p + b_size);
				p += b_size;

				Tensor memory w_tensor = new Tensor(w_array, dim[0], nxt_dim[0]);
				Tensor memory b_tensor = new Tensor(b_array, 1, nxt_dim[0]);
				uint activation = getActivationFromName(layersConfig[i + 1]);

				hiddenLayers.push(new DenseLayer(nxt_dim[0], activation, w_tensor, b_tensor));

				dim = nxt_dim;
			}
		}

		DenseLayer memory outputLayer = hiddenLayers.pop();

		Perceptron memory perceptron = new Perceptron(preprocessLayers, hiddenLayers, outputLayer);
		return { perceptron, inputDim };
	}

	function getInfo() public view returns (uint, uint[] memory, uint[] memory, uint[] memory, string memory, string[] memory) {
		(uint[] memory hiddenNeurons, uint[] memory activationFunc, uint[][][] memory parameters) = perceptron.getInfo();
		return (inputDim, parameters, hiddenNeurons, activationFunc, modelName, classesName);
	}

	function classifyImage(uint[] memory pixels) public view returns (uint[] memory) {
		Tensor memory img_tensor = new Tensor(pixels, 1, pixels.length);

		Tensor memory result_tensor = perceptron.forward(img_tensor);
		uint[] memory result = result_tensor.mat[0];

		return result;
	}
}

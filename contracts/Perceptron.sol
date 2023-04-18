// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


contract RescaleLayer {
	uint scale;
	uint offset;
}

contract FlattenLayer {
	uint[][] mat;

	function forward() public pure returns (uint[] memory) {
		return flat(mat);
	}
}

contract DenseLayer {
	uint out_dim;
	uint activation;
	uint[][] w;
	uint[] b;

	function forward(uint[][] memory x) public pure returns (uint[] memory) {
		uint[] memory y = add(matMul(x, w), b);
		uint[] memory z = (activation == 0) ? y : activation(y);
		return z;
	}
}

contract MultilayerPerceptron {
	RescaleLayer[] preprocessLayers;
	DenseLayer[] hiddenLayers;
	DenseLayer outputLayer;

	function getInfo() public pure returns (uint[] memory, uint, uint[][][] memory) {
		return (hiddenLayers.map(e => e.out_dim), hiddenLayers[0].activation, hiddenLayers.map(e => (e.w, e.b)));
	}

	function forward(uint[][] memory x) public pure returns (uint[] memory) {
		for (const layer of preprocessLayers) {
			x = layer.forward(x);
		}
		for (const layer of hiddenLayers) {
			x = layer.forward(x);
		}
		x = outputLayer.forward(x);
		return softmax(x);
	}
}

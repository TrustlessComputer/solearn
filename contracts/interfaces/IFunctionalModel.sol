// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainImplementation } from "./IOnchainImplementation.sol";

interface IFunctionalModel is IOnchainImplementation {
    struct Model {
        string modelName;
        uint256 requiredWeights;
        uint256 appendedWeights;
        uint256 ptrLayer;
        Info[] layers;
        Layers.InputScalarLayer[] inputScalar;
        Layers.InputTensor1DLayer[] inputTensor1D;
        Layers.InputTensor2DLayer[] inputTensor2D;
        Layers.InputTensor3DLayer[] inputTensor3D;
        Layers.RescaleLayer[] rescale;
        Layers.FlattenLayer[] flatten;
        Layers.DenseLayer[] dense;
        Layers.MaxPooling2DLayer[] maxPooling2D;
        Layers.Conv2DLayer[] conv2D;
        Layers.EmbeddingLayer[] embedding;
        Layers.SimpleRNNLayer[] simpleRNN;
        Layers.LSTM[] lstm;
    }

    function getInfo()
        external
        view
        returns (
            string memory modelName,
            Info[] memory layers,
            uint256 totalWeights
        );

    function setOnchainModel(
        bytes[] calldata layers_config
    ) external;

    function appendWeights(
        Float32x32[] memory weights
    ) external;
}
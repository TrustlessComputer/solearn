// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainImplementation } from "./IOnchainImplementation.sol";

interface IImageClassifier is IOnchainImplementation {
    struct Model {
        string modelName;
        string[] classesName;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Info[] layers;
        Layers.InputTensor3DLayer[] input;
        Layers.RescaleLayer[] rescale;
        Layers.FlattenLayer[] flatten;
        Layers.DenseLayer[] dense;
        Layers.MaxPooling2DLayer[] maxPooling2D;
        Layers.Conv2DLayer[] conv2D;
    }

    function getInfo()
        external
        view
        returns (
            uint256[3] memory inputDim,
            string memory modelName,
            string[] memory classesName,
            Info[] memory layers
        );

    function getDenseLayer(
        uint256 layerIdx
    )
        external
        view
        returns (
            uint256 dim_in,
            uint256 dim_out,
            Float32x32[][] memory w,
            Float32x32[] memory b
        );

    function getConv2DLayer(
        uint256 layerIdx
    )
        external
        view
        returns (
            uint256 n,
            uint256 m,
            uint256 p,
            uint256 q,
            Float32x32[][][][] memory w,
            Float32x32[] memory b
        );

    function setOnchainModel(
        bytes[] calldata layers_config
    ) external;

    function setClassesName(
        string[] memory classesName
    ) external;

    function appendWeights(
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external;
}
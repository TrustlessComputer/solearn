// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainModel } from "./IOnchainModel.sol";

interface IImageClassifier is IOnchainModel {
    event Classified(
        uint256 indexed tokenId,
        uint256 classIndex,
        string className,
        Float32x32[] outputs,
        Float32x32 confidence
    );

    event Forwarded(
        uint256 indexed tokenId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        Float32x32[][][] outputs1,
        Float32x32[] outputs2
    );

    struct Model {
        string modelName;
        string[] classesName;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Info[] layers;
        Layers.InputImageLayer[] input;
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
            uint256[3] memory,
            string memory,
            string[] memory,
            Info[] memory
        );

    function getDenseLayer(
        uint256 _modelId,
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
        uint256 _modelId,
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

    function classify(
        uint256 _modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        Float32x32[][][] calldata x1,
        Float32x32[] calldata x2
    ) external payable;

    function setOnchainModel(
        uint256 _modelId,
        bytes[] calldata layers_config
    ) external;

    function appendWeights(
        uint256 _modelId,
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external;
}
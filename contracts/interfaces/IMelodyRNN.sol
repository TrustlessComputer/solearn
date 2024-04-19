// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainModel } from "./IOnchainModel.sol";

interface IMelodyRNN is IOnchainModel {
    event NewMelody(uint256 indexed tokenId, Float32x32[] melody);

    event Forwarded(
        uint256 indexed tokenId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        Float32x32[][][] outputs1,
        Float32x32[] outputs2
    );

    struct Model {
        uint256[3] inputDim;
        string modelName;
        uint256 numLayers;
        Info[] layers;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Layers.RescaleLayer[] r;
        Layers.FlattenLayer[] f;
        Layers.DenseLayer[] d;
        Layers.LSTM[] lstm;
        Layers.EmbeddingLayer[] embedding;
    }
    
    struct VocabInfo {
        bool hasVocab;
        uint256[] vocabs;
    }

    function getInfo(
    )
        external
        view
        returns (
            uint256[3] memory,
            string memory,
            Info[] memory
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

    function getLSTMLayer(
        uint256 layerIdx
    )
        external
        view
        returns (
            uint256,
            uint256,
            Float32x32[][] memory,
            Float32x32[][] memory,
            Float32x32[] memory
        );

    function getVocabs() external view returns (uint256[] memory);

    function generateMelody(
        uint256 _modelId,
        uint256 noteCount,
        Float32x32[] calldata x
    ) external;

    function setModel(
        bytes[] calldata layers_config
    ) external;

    function appendWeights(
        Float32x32[] memory weights,
        uint256 layerInd,
        LayerType layerType
    ) external;
    
    function setVocabs(
        uint256[] memory vocabs
    ) external;
}
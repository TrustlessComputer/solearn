// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainImplementation } from "./IOnchainImplementation.sol";

interface IMelodyRNN is IOnchainImplementation {
    struct Model {
        string modelName;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Info[] layers;
        Layers.InputTokenLayer[] input;
        Layers.DenseLayer[] dense;
        Layers.LSTM[] lstm;
        Layers.EmbeddingLayer[] embedding;
    }
    
    struct VocabInfo {
        bool hasVocab;
        uint256[] vocabs;
    }

    function getInfo()
        external
        view
        returns (
            string memory modelName,
            uint256[] memory vocabs,
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

    function setOnchainModel(
        bytes[] calldata layers_config
    ) external;

    function appendWeights(
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external;
    
    function setVocabs(
        uint256[] memory vocabs
    ) external;

    function getVocabs() external view returns (uint256[] memory);
}
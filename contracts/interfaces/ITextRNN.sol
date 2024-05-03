// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainImplementation } from "./IOnchainImplementation.sol";

interface ITextRNN is IOnchainImplementation {
    // event TextGenerated(
    //     uint256 indexed tokenId,
    //     string result,
    //     Float32x32[][][] states,
    //     uint256 seed
    // );

    struct Model {
        string modelName;
        string[] classesName;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Info[] layers;
        Layers.InputTokenLayer[] input;
        Layers.DenseLayer[] dense;
        Layers.EmbeddingLayer[] embedding;
        Layers.SimpleRNNLayer[] simpleRNN;
        Layers.LSTM[] lstm;       
    }

    struct VocabInfo {
        string[] vocabs;
        mapping(bytes32 => uint256) hashToIndex;
        uint unkIndex;
    }

    function getInfo()
        external
        view
        returns (
            string memory modelName,
            string[] memory vocabs,
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
    
    // function generateText(
    //     string memory prompt,
    //     uint256 toGenerate,
    //     Float32x32[][][] memory states,
    //     uint256 seed
    // ) external;

    function setOnchainModel(
        bytes[] calldata layers_config
    ) external;

    function setVocabs(
        string[] memory vocabs,
        string memory unkToken
    ) external;
    
    function appendWeights(
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";
import { IOnchainModel } from "./IOnchainModel.sol";

interface IEternalAI is IOnchainModel {
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

    event TextGenerated(
        uint256 indexed tokenId,
        string result,
        Float32x32[][][] states,
        uint256 seed
    );

    struct Model {
        uint256[3] inputDim;
        string modelName;
        string[] classesName;
        uint256 numLayers;
        Info[] layers;
        uint256 requiredWeights;
        uint256 appendedWeights;
        Layers.RescaleLayer[] r;
        Layers.FlattenLayer[] f;
        Layers.DenseLayer[] d;
        Layers.MaxPooling2DLayer[] mp2;
        Layers.Conv2DLayer[] c2;
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

    function getLSTMLayer(
        uint256 _modelId,
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
        
    function classify(
        uint256 _modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        Float32x32[][][] calldata x1,
        Float32x32[] calldata x2
    ) external payable;
    
    function generateText(
        uint _modelId,
        string memory prompt,
        uint256 toGenerate,
        Float32x32[][][] memory states,
        uint256 seed
    ) external;

    function setEternalAI(
        uint256 _modelId,
        bytes[] calldata layers_config
    ) external;

    function appendWeights(
        uint256 _modelId,
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external;
    
    function setVocabs(
        uint256 _modelId,
        string[] memory vocabs,
        string memory unkToken
    ) external;
}
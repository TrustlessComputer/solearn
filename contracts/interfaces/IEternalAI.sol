// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SD59x18 } from "@prb/math/src/SD59x18.sol";

enum LayerType {
    Dense,
    Flatten,
    Rescale,
    Input,
    MaxPooling2D,
    Conv2D
}

struct Info {
    LayerType layerType;
    uint256 layerIndex;
}

interface IEternalAI {
    function getInfo(
        uint256 modelId
    ) 
        external 
        view 
        returns (
            uint256[3] memory inputDim, 
            string memory modelName, 
            string[] memory classesName, 
            Info[] memory layers
        );
    
    function getDenseLayer(
        uint256 modelId, 
        uint256 layerIdx
    ) 
        external 
        view 
        returns (
            uint256 dim_in, 
            uint256 dim_out, 
            SD59x18[][] memory w, 
            SD59x18[] memory b
        );
    
    function getConv2DLayer(
        uint256 modelId, 
        uint256 layerIdx
    ) 
        external 
        view 
        returns (
            uint256 n, 
            uint256 m, 
            uint256 p, 
            uint256 q, 
            SD59x18[][][][] memory w, 
            SD59x18[] memory b
        );

    function forward(
        uint256 modelId,
        SD59x18[][][][] memory x1,
        SD59x18[][] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) 
        external 
        view 
        returns (
            SD59x18[][][][] memory r1, 
            SD59x18[][] memory r2
        );

    function evaluate(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][][] calldata x1,
        SD59x18[][] calldata x2 
    ) 
        external 
        view 
        returns (
            string memory className, 
            SD59x18[][][][] memory r1, 
            SD59x18[][] memory r2
        );

    function classify(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][][] calldata x1,
        SD59x18[][] calldata x2
    ) external payable;

    function safeMint(address to, uint256 modelId, string memory uri, string memory modelName, string[] memory classesName) external payable;
    function setEternalAI(uint256 modelId, bytes[] calldata layers_config) external;
    function appendWeights(uint256 modelId, SD59x18[] memory weights, uint256 layerInd, LayerType layerType) external;
}
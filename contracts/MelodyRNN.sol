// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./lib/layers/Layers.sol";
import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientEvalPrice();
error TransferFailed();
error InvalidOutput();
error InvalidInput();


contract MelodyRNN is
    Initializable
{
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Layers for Layers.MaxPooling2DLayer;
    using Layers for Layers.Conv2DLayer;
    using Layers for Layers.EmbeddingLayer;
    using Layers for Layers.LSTM;
    using Tensor1DMethods for Tensors.Tensor1D;
    using Tensor2DMethods for Tensors.Tensor2D;
    using Tensor3DMethods for Tensors.Tensor3D;
    using Tensor4DMethods for Tensors.Tensor4D;

    Model public model;
    IERC721Upgradeable public modelRegistry;
    uint256 version;

    event Classified(
        uint256 indexed tokenId,
        uint256 classIndex,
        string className,
        SD59x18[] outputs
    );

    event Forwarded(
        uint256 indexed tokenId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] outputs1,
        SD59x18[] outputs2
    );

    event Deployed(
        address indexed owner,
        uint256 indexed tokenId
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
    }

    struct Info {
        LayerType layerType;
        uint256 layerIndex;
    }

    enum LayerType {
        Dense,
        Flatten,
        Rescale,
        Input,
        MaxPooling2D,
        Conv2D,
        Embedding,
        SimpleRNN,
        LSTM
    }

    function initialize(string memory _modelName) public initializer {
        model.modelName = _modelName;
        version = 1;
    }

    function afterUpgrade() public {}

    function getInfo(
        uint256 modelId
    )
        public
        view
        returns (
            uint256[3] memory,
            string memory,
            Info[] memory
        )
    {
        Model storage m = model;
        return (
            model.inputDim,
            model.modelName,
            m.layers
        );
    }

    function getDenseLayer(
        uint256 modelId,
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256 dim_in,
            uint256 dim_out,
            SD59x18[][] memory w,
            SD59x18[] memory b
        )
    {
        Layers.DenseLayer memory layer = model.d[layerIdx];
        dim_in = layer.w.n;
        dim_out = layer.w.m;
        w = layer.w.mat;
        b = layer.b.mat;
    }

    function forward(
        uint256 modelId,
        SD59x18[][][] memory x1,
        SD59x18[] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (SD59x18[][][] memory, SD59x18[] memory, SD59x18[][] memory states) {
        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }
        SD59x18[][] memory x2Ext;
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            Info memory layerInfo = model.layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Rescale) {
                x1 = model.r[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Flatten) {
                x2 = model.f[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2Ext = model.d[layerInfo.layerIndex].forward(x2Ext);
            } else if (layerInfo.layerType == LayerType.LSTM) {
                Layers.LSTM memory lstm = model.lstm[layerInfo.layerIndex];
                if (x2.length != lstm.inputUnits) revert InvalidInput();
                (x2Ext, states) = lstm.forward(x2, states);
            }
        }

        return (x1, x2Ext[0], states);
    }

    function evaluate(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    )
        public
        view
        returns (SD59x18, SD59x18[][][] memory, SD59x18[] memory)
    {
        (SD59x18[][][] memory r1, SD59x18[] memory r2, SD59x18[][] memory states) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == model.layers.length - 1) {
            if (r2.length != 1) revert InvalidOutput();
            return (r2[0], r1, r2);
        } else {
            return (sd(0), r1, r2);
        }
    }

    function generateMelody(
        uint256 modelId,
        uint256 noteCount,
        SD59x18[] calldata x
    ) public view returns (SD59x18[] memory) {
        SD59x18[] memory currentInput = x;
        SD59x18[][][] memory x1 = new SD59x18[][][](0);
        SD59x18[] memory result = new SD59x18[](noteCount);
        for (uint256 i=0; i<noteCount; i++) {
            (SD59x18[][][] memory r1, SD59x18[] memory r2, SD59x18[][] memory states) = forward(
                modelId,
                x1,
                currentInput,
                0,
                100
            );
            for (uint256 j=0; j<x.length-1; j++) {
                currentInput[j] = x[j+1];
            }
            currentInput[x.length-1] = r2[0];
            result[i] = r2[0];
        }

        return result;
    }

    function classify(
        uint256 tokenId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    ) external {
        uint256 modelId = tokenId;
        (SD59x18 output, SD59x18[][][] memory outputs1, SD59x18[] memory outputs2) = evaluate(
            modelId,
            fromLayerIndex,
            toLayerIndex,
            x1,
            x2
        );
    }

    function generateMelodyTest(
        uint256 modelId,
        uint256 noteCount,
        SD59x18[] calldata x
    ) external {
        SD59x18[] memory currentInput = x;
        SD59x18[][][] memory x1 = new SD59x18[][][](0);
        SD59x18[] memory result = new SD59x18[](noteCount);
        for (uint256 i=0; i<noteCount; i++) {
            (SD59x18[][][] memory r1, SD59x18[] memory r2, SD59x18[][] memory states) = forward(
                modelId,
                x1,
                currentInput,
                0,
                100
            );
            for (uint256 j=0; j<x.length-1; j++) {
                currentInput[j] = x[j+1];
            }
            currentInput[x.length-1] = r2[0];
            result[i] = r2[0];
        }
    }


    function setModel(
        uint256 modelId,
        bytes[] calldata layers_config
    ) external {
        if (msg.sender != modelRegistry.ownerOf(modelId)) revert NotTokenOwner();

        if (model.numLayers > 0) {
            model.numLayers = 0;
            delete model.d;
            delete model.f;
            delete model.r;
            delete model.lstm;
            delete model.layers;
        }

        loadModel(modelId, layers_config);
    }

    function appendWeights(
        uint256 modelId,
        SD59x18[] memory weights,
        uint256 layerInd,
        LayerType layerType
    ) external {
        uint appendedWeights;
        if (layerType == LayerType.Dense) {
            appendedWeights = model.d[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.LSTM) {
            appendedWeights = model.lstm[layerInd].appendWeights(weights);
        }
        
        model.appendedWeights += appendedWeights;
        if (model.appendedWeights == model.requiredWeights) {
            emit Deployed(msg.sender, modelId);
        }
    }

    function makeLayer(
        uint256 modelId,
        Layers.SingleLayerConfig memory slc,
        uint256[3] memory dim1,
        uint256 dim2
    ) internal returns (uint256[3] memory, uint256) {
        uint8 layerType = abi.decode(slc.conf, (uint8));

        // add more layers
        if (layerType == uint8(LayerType.Dense)) {
            (Layers.DenseLayer memory layer, uint out_dim2, uint weights) = Layers
                .makeDenseLayer(slc, dim2);
            model.d.push(layer);
            model.requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = model.d.length - 1;
            model.layers.push(Info(LayerType.Dense, index));
        } else if (layerType == uint8(LayerType.Flatten)) {
            (Layers.FlattenLayer memory layer, uint out_dim2) = Layers
                .makeFlattenLayer(slc, dim1);
            model.f.push(layer);
            dim2 = out_dim2;

            uint256 index = model.f.length - 1;
            model.layers.push(Info(LayerType.Flatten, index));
        } else if (layerType == uint8(LayerType.Rescale)) {
            Layers.RescaleLayer memory layer = Layers.makeRescaleLayer(slc);
            model.r.push(layer);

            uint256 index = model.r.length - 1;
            model.layers.push(Info(LayerType.Rescale, index));
        } else if (layerType == uint8(LayerType.Input)) {
            (, uint8 inputType) = abi.decode(slc.conf, (uint8, uint8));
            if (inputType == 0) {
                dim2 = 1;
            } else if (inputType == 1) {
                (, , uint256[3] memory ipd) = abi.decode(
                    slc.conf,
                    (uint8, uint8, uint256[3])
                );
                model.inputDim = ipd;
                dim1 = ipd;
            }

            // NOTE: there is only one layer type input
            model.layers.push(Info(LayerType.Input, 0));
        } else if (layerType == uint8(LayerType.LSTM)) {
            (Layers.LSTM memory layer, uint out_dim) = Layers
                .makeLSTMLayer(slc, dim2);
            model.lstm.push(layer);
            dim1 = dim1;
            dim2 = out_dim;

            uint256 index = model.lstm.length - 1;
            model.layers.push(Info(LayerType.LSTM, index));
        }
        return (dim1, dim2);
    }

    function loadModel(
        uint256 modelId,
        bytes[] calldata layersConfig
    ) internal {
        model.numLayers = layersConfig.length;
        model.requiredWeights = 0;
        model.appendedWeights = 0;
        uint256[3] memory dim1;
        uint256 dim2;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            (dim1, dim2) = makeLayer(
                modelId,
                Layers.SingleLayerConfig(layersConfig[i], i),
                dim1,
                dim2
            );
        }
    }
}

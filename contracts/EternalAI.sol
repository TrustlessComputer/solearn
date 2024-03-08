// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./lib/layers/Layers.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error IncorrectModelId();

interface IModelReg is IERC721Upgradeable {
    function modelAddr(uint256 tokenId) external view returns (address);
}

contract EternalAI is
    Initializable
{
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Layers for Layers.MaxPooling2DLayer;
    using Layers for Layers.Conv2DLayer;
    using Layers for Layers.EmbeddingLayer;
    using Layers for Layers.SimpleRNNLayer;
    using Tensor1DMethods for Tensors.Tensor1D;
    using Tensor2DMethods for Tensors.Tensor2D;
    using Tensor3DMethods for Tensors.Tensor3D;
    using Tensor4DMethods for Tensors.Tensor4D;

    Model public model;
    IModelReg public modelRegistry;
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
        SimpleRNN
    }

    function initialize(string memory _modelName, address _modelRegistry) public initializer {
        model.modelName = _modelName;
        modelRegistry = IModelReg(_modelRegistry);      
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
            string[] memory,
            Info[] memory
        )
    {
        Model storage m = model;
        return (
            model.inputDim,
            model.modelName,
            model.classesName,
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

    function getConv2DLayer(
        uint256 modelId,
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256 n,
            uint256 m,
            uint256 p,
            uint256 q,
            SD59x18[][][][] memory w,
            SD59x18[] memory b
        )
    {
        Layers.Conv2DLayer memory layer = model.c2[layerIdx];
        n = layer.w.n;
        m = layer.w.m;
        p = layer.w.p;
        q = layer.w.q;
        w = layer.w.mat;
        b = layer.b.mat;
    }

    function forward(
        uint256 modelId,
        SD59x18[][][] memory x1,
        SD59x18[] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (SD59x18[][][] memory, SD59x18[] memory) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            Info memory layerInfo = model.layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Rescale) {
                x1 = model.r[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Flatten) {
                x2 = model.f[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2 = model.d[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == LayerType.MaxPooling2D) {
                x1 = model.mp2[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Conv2D) {
                x1 = model.c2[layerInfo.layerIndex].forward(x1);
            }

            // the last layer
            if (i == model.layers.length - 1) {
                Tensors.Tensor1D memory xt = Tensor1DMethods.from(x2);
                SD59x18[] memory result = xt.softmax().mat;
                return (x1, result);
            }
        }

        return (x1, x2);
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
        returns (string memory, SD59x18[][][] memory, SD59x18[] memory)
    {
        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == model.layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2.length; i++) {
                if (r2[i].gt(r2[maxInd])) {
                    maxInd = i;
                }
            }

            return (model.classesName[maxInd], r1, r2);
        } else {
            return ("", r1, r2);
        }
    }

    function classify(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    ) external payable {
        // NOTE: TODO uncomment for mainnet
        // if (msg.value < evalPrice) revert InsufficientEvalPrice();

        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == model.layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2.length; i++) {
                if (r2[i].gt(r2[maxInd])) {
                    maxInd = i;
                }
            }

            emit Classified(
                modelId,
                maxInd,
                model.classesName[maxInd],
                r2
            );
        } else {
            emit Forwarded(modelId, fromLayerIndex, toLayerIndex, r1, r2);
        }

        // NOTE: TODO uncomment for mainnet
        // uint256 protocolFee = (msg.value * protocolFeePercent) / 100;
        // uint256 royalty = msg.value - protocolFee;
        // (bool success, ) = address(ownerOf(modelId)).call{value: royalty}("");
        // if (!success) revert TransferFailed();
    }

    function setEternalAI(
        uint256 modelId,
        bytes[] calldata layers_config
    ) external {
        if (msg.sender != modelRegistry.ownerOf(modelId)) revert NotTokenOwner();
        if (address(this) != modelRegistry.modelAddr(modelId)) revert IncorrectModelId();

        if (model.numLayers > 0) {
            model.numLayers = 0;
            delete model.d;
            delete model.f;
            delete model.r;
            delete model.c2;
            delete model.mp2;
            delete model.embedding;
            delete model.simpleRNN;
            delete model.layers;
        }

        loadEternalAI(layers_config);
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
        } else if (layerType == LayerType.Conv2D) {
            appendedWeights = model.c2[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Embedding) {
            appendedWeights = model.embedding[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.SimpleRNN) {
            appendedWeights = model.simpleRNN[layerInd].appendWeights(weights);
        }
        model.appendedWeights += appendedWeights;
        if (model.appendedWeights == model.requiredWeights) {
            emit Deployed(msg.sender, modelId);
        }
    }

    function makeLayer(
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
        } else if (layerType == uint8(LayerType.MaxPooling2D)) {
            (
                Layers.MaxPooling2DLayer memory layer,
                uint[3] memory out_dim1
            ) = Layers.makeMaxPooling2DLayer(slc, dim1);
            model.mp2.push(layer);
            dim1 = out_dim1;

            uint256 index = model.mp2.length - 1;
            model.layers.push(Info(LayerType.MaxPooling2D, index));
        } else if (layerType == uint8(LayerType.Conv2D)) {
            (Layers.Conv2DLayer memory layer, uint[3] memory out_dim1, uint weights) = Layers
                .makeConv2DLayer(slc, dim1);
            model.c2.push(layer);
            model.requiredWeights += weights;
            dim1 = out_dim1;

            uint256 index = model.c2.length - 1;
            model.layers.push(Info(LayerType.Conv2D, index));
        } else if (layerType == uint8(LayerType.Embedding)) {
            (Layers.EmbeddingLayer memory layer, uint out_dim2, uint weights) = Layers
                .makeEmbeddingLayer(slc);
            model.embedding.push(layer);
            model.requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = model.embedding.length - 1;
            model.layers.push(Info(LayerType.Embedding, index));
        } else if (layerType == uint8(LayerType.SimpleRNN)) {
            (Layers.SimpleRNNLayer memory layer, uint out_dim2, uint weights) = Layers
                .makeSimpleRNNLayer(slc, dim2);
            model.simpleRNN.push(layer);
            model.requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = model.simpleRNN.length - 1;
            model.layers.push(Info(LayerType.SimpleRNN, index));
        }
        return (dim1, dim2);
    }

    function loadEternalAI(
        bytes[] calldata layersConfig
    ) internal {
        model.numLayers = layersConfig.length;
        model.requiredWeights = 0;
        model.appendedWeights = 0;
        uint256[3] memory dim1;
        uint256 dim2;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            (dim1, dim2) = makeLayer(
                Layers.SingleLayerConfig(layersConfig[i], i),
                dim1,
                dim2
            );
        }
    }
}

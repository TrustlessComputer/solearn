// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./lib/layers/Layers.sol";
import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error InvalidOutput();


contract MelodyRNN is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
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

    mapping(uint256 => Model) public models;
    uint256 public mintPrice;
    uint256 public evalPrice;
    uint8 protocolFeePercent;
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function initialize() public initializer {
        __ERC721_init("MelodyRNN", "MRNN");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        // NOTE: set fee = 0 for testnet
        mintPrice = 0 ether;
        evalPrice = 0 ether;
        protocolFeePercent = 50;
        // mintPrice = 0.01 ether;
        // evalPrice = 0.0001 ether;
        // protocolFeePercent = 50;
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
        Model storage m = models[modelId];
        return (
            models[modelId].inputDim,
            models[modelId].modelName,
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
        Layers.DenseLayer memory layer = models[modelId].d[layerIdx];
        dim_in = layer.w.n;
        dim_out = layer.w.m;
        w = layer.w.mat;
        b = layer.b.mat;
    }

    function safeMint(
        address to,
        uint256 modelId,
        string memory uri,
        string memory modelName
    ) external payable {
        // if (msg.value < mintPrice) revert InsufficientMintPrice();

        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        models[modelId].modelName = modelName;
    }

    function forward(
        uint256 modelId,
        SD59x18[][][] memory x1,
        SD59x18[] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (SD59x18[][][] memory, SD59x18[] memory, SD59x18[][] memory states) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            Info memory layerInfo = models[modelId].layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Rescale) {
                x1 = models[modelId].r[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Flatten) {
                x2 = models[modelId].f[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2 = models[modelId].d[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == LayerType.LSTM) {
                SD59x18[][] memory x2Ext;
                // uint256 gasUsed;
                // (x2Ext, states, gasUsed) = models[modelId].lstm[layerInfo.layerIndex].forward(x2, states);
                x2 = x2Ext[0];
            }
        }

        return (x1, x2, states);
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
        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2, SD59x18[][] memory states) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            if (r2.length != 1) revert InvalidOutput();
            return (r2[0], r1, r2);
        } else {
            return (sd(0), r1, r2);
        }
    }

    function setModel(
        uint256 modelId,
        bytes[] calldata layers_config
    ) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();

        if (models[modelId].numLayers > 0) {
            models[modelId].numLayers = 0;
            delete models[modelId].d;
            delete models[modelId].f;
            delete models[modelId].r;
            delete models[modelId].lstm;
            delete models[modelId].layers;
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
            appendedWeights = models[modelId].d[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.LSTM) {
            appendedWeights = models[modelId].lstm[layerInd].appendWeights(weights);
        }
        
        models[modelId].appendedWeights += appendedWeights;
        if (models[modelId].appendedWeights == models[modelId].requiredWeights) {
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
            models[modelId].d.push(layer);
            models[modelId].requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = models[modelId].d.length - 1;
            models[modelId].layers.push(Info(LayerType.Dense, index));
        } else if (layerType == uint8(LayerType.Flatten)) {
            (Layers.FlattenLayer memory layer, uint out_dim2) = Layers
                .makeFlattenLayer(slc, dim1);
            models[modelId].f.push(layer);
            dim2 = out_dim2;

            uint256 index = models[modelId].f.length - 1;
            models[modelId].layers.push(Info(LayerType.Flatten, index));
        } else if (layerType == uint8(LayerType.Rescale)) {
            Layers.RescaleLayer memory layer = Layers.makeRescaleLayer(slc);
            models[modelId].r.push(layer);

            uint256 index = models[modelId].r.length - 1;
            models[modelId].layers.push(Info(LayerType.Rescale, index));
        } else if (layerType == uint8(LayerType.Input)) {
            (, uint8 inputType) = abi.decode(slc.conf, (uint8, uint8));
            if (inputType == 0) {
                dim2 = 1;
            } else if (inputType == 1) {
                (, , uint256[3] memory ipd) = abi.decode(
                    slc.conf,
                    (uint8, uint8, uint256[3])
                );
                models[modelId].inputDim = ipd;
                dim1 = ipd;
            }

            // NOTE: there is only one layer type input
            models[modelId].layers.push(Info(LayerType.Input, 0));
        } else if (layerType == uint8(LayerType.LSTM)) {
            (Layers.LSTM memory layer, uint out_dim) = Layers
                .makeLSTMLayer(slc, dim2);
            models[modelId].lstm.push(layer);
            dim1 = dim1;
            dim2 = out_dim;

            uint256 index = models[modelId].lstm.length - 1;
            models[modelId].layers.push(Info(LayerType.LSTM, index));
        }
        return (dim1, dim2);
    }

    function loadModel(
        uint256 modelId,
        bytes[] calldata layersConfig
    ) internal {
        models[modelId].numLayers = layersConfig.length;
        models[modelId].requiredWeights = 0;
        models[modelId].appendedWeights = 0;
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

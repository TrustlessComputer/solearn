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
import "./Layers.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();

contract UnstoppableAI is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Tensors for Tensors.Tensor;

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
        SD59x18[][] outputs
    );

    struct Model {
        uint256[3] inputDim;
        string modelName;
        string[] classesName;
        uint256 numLayers;
        Layers.RescaleLayer[] r;
        Layers.FlattenLayer[] f;
        Layers.DenseLayer[] d;
        Info[] layers;
    }

    struct Info {
        LayerType layerType;
        uint256 layerIndex;
    }

    struct LayerTypeIndexes {
        uint256 rescaleLayerIndex;
        uint256 flattenLayerIndex;
        uint256 denseLayerIndex;
    }

    struct SingleLayerConfig {
        bytes conf;
        uint256 ind;
        uint256 prevDim;
        uint256 ptr;
    }

    enum LayerType {
        Dense,
        Flatten,
        Rescale,
        Input
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
        __ERC721_init("Perceptron", "PCT");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        mintPrice = 0.01 ether;
        evalPrice = 0.0001 ether;
        protocolFeePercent = 50;
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
            SD59x18[][][] memory,
            uint256[] memory,
            string memory,
            string[] memory,
            Info[] memory
        )
    {
        Model storage m = models[modelId];
        uint256[] memory out_dim = new uint256[](m.d.length);
        SD59x18[][][] memory w_b = new SD59x18[][][](m.d.length);
        for (uint256 i = 0; i < m.d.length; i++) {
            out_dim[i] = m.d[i].out_dim;
            w_b[i] = new SD59x18[][](2);
            w_b[i][0] = Tensors.flat(m.d[i].w);
            w_b[i][1] = m.d[i].b;
        }

        return (
            models[modelId].inputDim,
            w_b,
            out_dim,
            models[modelId].modelName,
            models[modelId].classesName,
            m.layers
        );
    }

    function safeMint(
        address to,
        uint256 modelId,
        string memory uri,
        string memory modelName,
        string[] memory classesName
    ) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();
        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        models[modelId].modelName = modelName;
        for (uint256 i = 0; i < classesName.length; i++) {
            models[modelId].classesName.push(classesName[i]);
        }
    }

    function forward(
        uint256 modelId,
        SD59x18[][] memory x,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (SD59x18[][] memory) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            Info memory layerInfo = models[modelId].layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Rescale) {
                x = models[modelId].r[layerInfo.layerIndex].forward(x);
            } else if (layerInfo.layerType == LayerType.Flatten) {
                x = models[modelId].f[layerInfo.layerIndex].forward(x);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x = models[modelId].d[layerInfo.layerIndex].forward(x);
            }

            // the last layer
            if (i == models[modelId].layers.length - 1) {
                Tensors.Tensor memory xt;
                xt.from(x);
                SD59x18[][] memory result = new SD59x18[][](1);
                result[0] = Tensors.flat(xt.softmax().mat);
                return result;
            }
        }

        return x;
    }

    function evaluate(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[] memory pixels,
        SD59x18[][] memory pixelMat
    ) public view returns (string memory, SD59x18[][] memory) {
        if (pixelMat.length == 0) {
            Tensors.Tensor memory img_tensor;
            img_tensor.load(pixels, 1, pixels.length);
            pixelMat = img_tensor.mat;
        }

        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        SD59x18[][] memory result = forward(
            modelId,
            pixelMat,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < result[0].length; i++) {
                if (result[0][i].gt(result[0][maxInd])) {
                    maxInd = i;
                }
            }

            return (models[modelId].classesName[maxInd], result);
        } else {
            return ("", result);
        }
    }

    function classify(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[] memory pixels,
        SD59x18[][] memory pixelMat
    ) external payable {
        if (msg.value < evalPrice) revert InsufficientEvalPrice();

        if (pixelMat.length == 0) {
            Tensors.Tensor memory img_tensor;
            img_tensor.load(pixels, 1, pixels.length);
            pixelMat = img_tensor.mat;
        }

        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        SD59x18[][] memory result = forward(
            modelId,
            pixelMat,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < result[0].length; i++) {
                if (result[0][i].gt(result[0][maxInd])) {
                    maxInd = i;
                }
            }

            emit Classified(
                modelId,
                maxInd,
                models[modelId].classesName[maxInd],
                result[0]
            );
        } else {
            emit Forwarded(modelId, fromLayerIndex, toLayerIndex, result);
        }

        uint256 protocolFee = (msg.value * protocolFeePercent) / 100;
        uint256 royalty = msg.value - protocolFee;
        (bool success, ) = address(ownerOf(modelId)).call{value: royalty}("");
        if (!success) revert TransferFailed();
    }

    function setWeights(
        uint256 modelId,
        bytes[] memory layers_config,
        SD59x18[][][] calldata weights,
        SD59x18[][] calldata biases,
        int appendLayer
    ) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();
        if (appendLayer < 0) {
            if (models[modelId].numLayers > 0) {
                models[modelId].numLayers = 0;
                delete models[modelId].d;
                delete models[modelId].f;
                delete models[modelId].r;
                delete models[modelId].layers;
            }

            loadPerceptron(modelId, layers_config, weights, biases);
        } else {
            appendWeights(modelId, weights[0], uint256(appendLayer));
        }
    }

    function appendWeights(
        uint256 modelId,
        SD59x18[][] memory weights,
        uint256 layerInd
    ) internal {
        for (uint256 i = 0; i < weights.length; i++) {
            models[modelId].d[layerInd].w.push(weights[i]);
        }
    }

    function makeLayer(
        uint256 modelId,
        SingleLayerConfig memory slc,
        SD59x18[][][] memory weights,
        SD59x18[][] memory biases
    ) internal returns (uint256, uint256) {
        uint8 layerType = abi.decode(slc.conf, (uint8));
        uint256 dim = 0;

        // add more layers
        if (layerType == uint8(LayerType.Dense)) {
            (uint8 _t, uint8 actv, uint256 d) = abi.decode(
                slc.conf,
                (uint8, uint8, uint256)
            );
            Layers.DenseLayer memory temp = Layers.DenseLayer(
                slc.ind,
                Layers.ActivationFunc(actv),
                d,
                weights[slc.ptr],
                biases[slc.ptr]
            );
            models[modelId].d.push(temp);
            uint256 index = models[modelId].d.length - 1;
            Info memory layerInfo = Info(LayerType.Dense, index);
            models[modelId].layers.push(layerInfo);
            slc.ptr++;

            dim = d;
        } else if (layerType == uint8(LayerType.Flatten)) {
            uint256 len = models[modelId].f.length;
            Layers.FlattenLayer memory temp;
            models[modelId].f.push(temp);
            models[modelId].f[len].layerIndex = slc.ind;
            dim = slc.prevDim;

            uint256 index = models[modelId].f.length - 1;
            Info memory layerInfo = Info(LayerType.Flatten, index);
            models[modelId].layers.push(layerInfo);
        } else if (layerType == uint8(LayerType.Rescale)) {
            uint256 len = models[modelId].r.length;
            Layers.RescaleLayer memory temp;
            models[modelId].r.push(temp);
            (uint8 _t, SD59x18 scale, SD59x18 offset) = abi.decode(
                slc.conf,
                (uint8, SD59x18, SD59x18)
            );
            models[modelId].r[len].layerIndex = slc.ind;
            models[modelId].r[len].scale = scale;
            models[modelId].r[len].offset = offset;
            dim = slc.prevDim;
            Info memory layerInfo = Info(LayerType.Rescale, len);
            models[modelId].layers.push(layerInfo);
        } else if (layerType == uint8(LayerType.Input)) {
            (uint8 _t, uint256[3] memory ipd) = abi.decode(
                slc.conf,
                (uint8, uint256[3])
            );
            models[modelId].inputDim = ipd;
            dim = ipd[0] * ipd[1] * ipd[2];

            // NOTE: there is only one layer type input
            Info memory layerInfo = Info(LayerType.Input, 0);
            models[modelId].layers.push(layerInfo);
        }

        return (slc.ptr, dim);
    }

    function loadPerceptron(
        uint256 modelId,
        bytes[] memory layersConfig,
        SD59x18[][][] calldata weights,
        SD59x18[][] calldata biases
    ) internal {
        models[modelId].numLayers = layersConfig.length;
        uint256 ptr = 0;
        uint256 dim = 0;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            (ptr, dim) = makeLayer(
                modelId,
                SingleLayerConfig(layersConfig[i], i, dim, ptr),
                weights,
                biases
            );
        }
    }
}

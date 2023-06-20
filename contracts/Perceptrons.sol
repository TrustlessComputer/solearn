// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";
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

contract Perceptrons is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable {
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Tensors for Tensors.Tensor;

    mapping(uint256 => Model) public models;
    uint256 public mintPrice;
    uint256 public evalPrice;
    uint8 protocolFeePercent;
    uint256 version;

    event Classified(uint256 indexed tokenId, uint256 classIndex, string className, SD59x18[] outputs);

    struct Model {
        uint256[3] inputDim;
        string modelName;
        string[] classesName;

        uint256 numLayers;
        Layers.RescaleLayer[] r;
        Layers.FlattenLayer[] f;
        Layers.DenseLayer[] d;
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

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function initialize() initializer public {
        __ERC721_init("Perceptron", "PCT");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        mintPrice = 0.01 ether;
        evalPrice = 0.0001 ether;
        protocolFeePercent = 50;
        version = 1;
    }

    function afterUpgrade() public {

    }


    function getInfo(uint256 modelId) public view returns (uint256[3] memory, SD59x18[][][] memory, uint256[] memory, string memory, string[] memory) {
        Model storage m = models[modelId];
        uint256[] memory out_dim = new uint256[](m.d.length);
        SD59x18[][][] memory w_b = new SD59x18[][][](m.d.length);
        for (uint256 i = 0; i < m.d.length; i++) {
            out_dim[i] = m.d[i].out_dim;
            w_b[i] = new SD59x18[][](2);
            w_b[i][0] = Tensors.flat(m.d[i].w);
            w_b[i][1] = m.d[i].b;
        }
        
        return (models[modelId].inputDim, w_b, out_dim, models[modelId].modelName, models[modelId].classesName);
    }

    function safeMint(address to, uint256 modelId, string memory uri, string memory modelName, string[] memory classesName) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();
        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        models[modelId].modelName = modelName;
        for (uint256 i = 0; i < classesName.length; i++) {
            models[modelId].classesName.push(classesName[i]);
        }
    }

    function evaluateToIndex(uint256 modelId, SD59x18[] memory pixels) public view returns (uint256) {
        Tensors.Tensor memory img_tensor;
        img_tensor.load(pixels, 1, pixels.length);

        SD59x18[] memory result = forward(modelId, img_tensor.mat);
        uint256 maxInd = 0;
        for (uint256 i = 1; i < result.length; i++) {
            if (result[i].gt(result[maxInd])) {
                maxInd = i;
            }
        }

        return maxInd;
    }

    function evaluate(uint256 modelId, SD59x18[] memory pixels) public view returns (string memory) {
        Tensors.Tensor memory img_tensor;
        img_tensor.load(pixels, 1, pixels.length);

        SD59x18[] memory result = forward(modelId, img_tensor.mat);
        uint256 maxInd = 0;
        for (uint256 i = 1; i < result.length; i++) {
            if (result[i].gt(result[maxInd])) {
                maxInd = i;
            }
        }

        return models[modelId].classesName[maxInd];
    }

    function classify(uint256 modelId, SD59x18[] memory pixels) external payable {
        if (msg.value < evalPrice) revert InsufficientEvalPrice();
        Tensors.Tensor memory img_tensor;
        img_tensor.load(pixels, 1, pixels.length);

        SD59x18[] memory result = forward(modelId, img_tensor.mat);
        uint256 maxInd = 0;
        for (uint256 i = 1; i < result.length; i++) {
            if (result[i].gt(result[maxInd])) {
                maxInd = i;
            }
        }

        emit Classified(modelId, maxInd, models[modelId].classesName[maxInd], result);

        uint256 protocolFee = msg.value * protocolFeePercent / 100;
        uint256 royalty = msg.value - protocolFee;
        (bool success,) = address(ownerOf(modelId)).call{value: royalty}("");
        if (!success) revert TransferFailed();
    }

    function forward(uint256 modelId, SD59x18[][] memory x) public view returns (SD59x18[] memory) {
        LayerTypeIndexes memory lti;
        for (uint256 i = 0; i < models[modelId].numLayers; i++) {
            if (lti.rescaleLayerIndex < models[modelId].r.length && models[modelId].r[lti.rescaleLayerIndex].layerIndex == i) {
                x = models[modelId].r[lti.rescaleLayerIndex].forward(x);

                // console.logInt(models[modelId].r[lti.rescaleLayerIndex].scale.unwrap());
                // console.logInt(models[modelId].r[lti.rescaleLayerIndex].offset.unwrap());
                lti.rescaleLayerIndex++;
                // console.log("#%s is rescale -> x dimensions %s %s", i, x.length, x[0].length);
            } else if (lti.flattenLayerIndex < models[modelId].f.length && models[modelId].f[lti.flattenLayerIndex].layerIndex == i) {
                x = models[modelId].f[lti.flattenLayerIndex].forward(x);
                lti.flattenLayerIndex++;
                // console.log("#%s is flatten -> x dimensions %s %s", i, x.length, x[0].length);
            } else if (lti.denseLayerIndex < models[modelId].d.length && models[modelId].d[lti.denseLayerIndex].layerIndex == i) {
                x = models[modelId].d[lti.denseLayerIndex].forward(x);
                lti.denseLayerIndex++;
                // console.log("#%s is dense -> x dimensions %s %s", i, x.length, x[0].length);
            }

            // if (x.length == 1 && x[0].length < 50) {
            //     for (uint256 i2 = 0; i2 < x[0].length; i2++) {
            //         console.logInt(x[0][i2].unwrap());
            //     }
            // } else {
            //     console.logInt(x[0][0].unwrap());
            //     console.logInt(x[0][x[0].length - 1].unwrap());
            // }
        }

        // console.log("x dimensions %s %s", x.length, x[0].length);
        // if (x.length == 1 && x[0].length < 50) {
        //     for (uint256 i = 0; i < x[0].length; i++) {
        //         console.logInt(x[0][i].unwrap());
        //     }
        // }

        Tensors.Tensor memory xt;
        xt.from(x);
        return Tensors.flat(xt.softmax().mat);
    }

    function setWeights(uint256 modelId, bytes[] memory layers_config, SD59x18[][][] calldata weights, SD59x18[][] calldata biases, int appendLayer) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();
        if (appendLayer < 0) {
            if (models[modelId].numLayers > 0) {
                models[modelId].numLayers = 0;
                delete models[modelId].d;
                delete models[modelId].f;
                delete models[modelId].r;
            }

            loadPerceptron(modelId, layers_config, weights, biases);
        } else {
            appendWeights(modelId, weights[0], uint256(appendLayer));
        }
    }

    function appendWeights(uint256 modelId, SD59x18[][] memory weights, uint256 layerInd) internal {
        for (uint256 i = 0; i < weights.length; i++) {
            models[modelId].d[layerInd].w.push(weights[i]);
        }
    }

    function makeLayer(uint256 modelId, SingleLayerConfig memory slc, SD59x18[][][] memory weights, SD59x18[][] memory biases) internal returns (uint256, uint256) {
        uint8 layerType = abi.decode(slc.conf, (uint8));
        uint256 dim = 0;
        
        if (layerType == uint8(LayerType.Dense)) {
            (uint8 _t, uint8 actv, uint256 d) = abi.decode(slc.conf, (uint8, uint8, uint256));
            Layers.DenseLayer memory temp = Layers.DenseLayer(slc.ind, Layers.ActivationFunc(actv), d, weights[slc.ptr], biases[slc.ptr]);
            models[modelId].d.push(temp);
            slc.ptr++;
        
            dim = d;
        } else if (layerType == uint8(LayerType.Flatten)) {
            uint256 len = models[modelId].d.length;
            Layers.FlattenLayer memory temp;
            models[modelId].f.push(temp);
            models[modelId].f[len].layerIndex = slc.ind;
            dim = slc.prevDim;
        } else if (layerType == uint8(LayerType.Rescale)) {
            uint256 len = models[modelId].r.length;
            Layers.RescaleLayer memory temp;
            models[modelId].r.push(temp);
            (uint8 _t, SD59x18 scale, SD59x18 offset) = abi.decode(slc.conf, (uint8, SD59x18, SD59x18));
            models[modelId].r[len].layerIndex = slc.ind;
            models[modelId].r[len].scale = scale;
            models[modelId].r[len].offset = offset;
            dim = slc.prevDim;
        } else if (layerType == uint8(LayerType.Input)) {
            (uint8 _t, uint256[3] memory ipd) = abi.decode(slc.conf, (uint8, uint256[3]));
            models[modelId].inputDim = ipd;
            dim = ipd[0] * ipd[1] * ipd[2];
        }

        return (slc.ptr, dim);
    }

    function loadPerceptron(uint256 modelId, bytes[] memory layersConfig, SD59x18[][][] calldata weights, SD59x18[][] calldata biases) internal {
        models[modelId].numLayers = layersConfig.length;
        uint256 ptr = 0;
        uint256 dim = 0;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            (ptr, dim) = makeLayer(modelId, SingleLayerConfig(layersConfig[i], i, dim, ptr), weights, biases);
        }
    }
}


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

contract Perceptrons is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable {
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Tensors for Tensors.Tensor;

    mapping(uint => Model) public models;
    uint public mintPrice;

    struct Model {
        uint[3] inputDim;
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
        uint ind;
        uint prevDim;
        uint ptr;
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
    }

    function afterUpgrade() public {

    }


    function getInfo(uint256 modelId) public view returns (uint[3] memory, SD59x18[][][] memory, uint[] memory, string memory, string[] memory) {
        Model storage m = models[modelId];
        uint[] memory out_dim = new uint[](m.d.length);
        SD59x18[][][] memory w_b = new SD59x18[][][](m.d.length);
        for (uint i = 0; i < m.d.length; i++) {
            out_dim[i] = m.d[i].out_dim;
            w_b[i] = new SD59x18[][](2);
            w_b[i][0] = Tensors.flat(m.d[i].w);
            w_b[i][1] = m.d[i].b;
        }
        
        return (models[modelId].inputDim, w_b, out_dim, models[modelId].modelName, models[modelId].classesName);
    }

    function safeMint(address to, uint modelId, string memory uri, string memory modelName, string[] memory classesName) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();
        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        models[modelId].modelName = modelName;
        for (uint i = 0; i < models[modelId].classesName.length; i++) {
            models[modelId].classesName.push(classesName[i]);
        }
    }

    function classify(uint256 modelId, SD59x18[] memory pixels) public view returns (SD59x18[] memory) {
        Tensors.Tensor memory img_tensor;
        img_tensor.load(pixels, 1, pixels.length);

        SD59x18[] memory result = forward(modelId, img_tensor.mat);

        return result;
    }

    function forward(uint256 modelId, SD59x18[][] memory x) public view returns (SD59x18[] memory) {
        LayerTypeIndexes memory lti;
        for (uint256 i = 0; i < models[modelId].numLayers; i++) {
            if (models[modelId].r[lti.rescaleLayerIndex].layerIndex == i) {
                x = models[modelId].r[lti.rescaleLayerIndex].forward(x);
                lti.rescaleLayerIndex++;
            } else if (models[modelId].f[lti.flattenLayerIndex].layerIndex == i) {
                x = models[modelId].f[lti.flattenLayerIndex].forward(x);
                lti.flattenLayerIndex++;
            } else if (models[modelId].d[lti.denseLayerIndex].layerIndex == i) {
                x = models[modelId].d[lti.denseLayerIndex].forward(x);
                lti.denseLayerIndex++;
            }
        }

        Tensors.Tensor memory xt;
        xt.from(x);
        return Tensors.flat(xt.softmax().mat);
    }

    function setWeights(uint256 modelId, bytes[] memory layers_config, SD59x18[] calldata weights) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();
        loadPerceptron(modelId, layers_config, weights);
    }

    function makeLayer(uint256 modelId, SingleLayerConfig memory slc, SD59x18[] calldata weights) internal returns (uint, uint) {
        uint8 layerType = abi.decode(slc.conf, (uint8));
        uint dim = 0;
        
        if (layerType == uint8(LayerType.Dense)) {
            (uint8 _t, uint8 actv, uint d) = abi.decode(slc.conf, (uint8, uint8, uint));
            uint len = models[modelId].d.length;
            {
                Layers.DenseLayer memory temp = Layers.DenseLayer(slc.ind, Layers.ActivationFunc(actv), d, new SD59x18[][](0), new SD59x18[](0));
                models[modelId].d.push(temp);
            }

            if (weights.length > 0) {
                for (uint i = 0; i < slc.prevDim; i++) {
                    models[modelId].d[len].w.push(new SD59x18[](0));
                    for (uint j = 0; j < d; j++) {
                        models[modelId].d[len].w[i].push(weights[slc.ptr++]);
                    }
                }
                for (uint i = 0; i < d; i++) {
                    models[modelId].d[len].b.push(weights[slc.ptr++]);
                }
            }
        
            dim = d;
        } else if (layerType == uint8(LayerType.Flatten)) {
            uint len = models[modelId].d.length;
            Layers.FlattenLayer memory temp;
            models[modelId].f.push(temp);
            models[modelId].f[len].layerIndex = slc.ind;
            dim = slc.prevDim;
        } else if (layerType == uint8(LayerType.Rescale)) {
            uint len = models[modelId].r.length;
            Layers.RescaleLayer memory temp;
            models[modelId].r.push(temp);
            (uint8 _t, SD59x18 scale, SD59x18 offset) = abi.decode(slc.conf, (uint8, SD59x18, SD59x18));
            models[modelId].r[len].layerIndex = slc.ind;
            models[modelId].r[len].scale = scale;
            models[modelId].r[len].offset = offset;
            dim = slc.prevDim;
        } else if (layerType == uint8(LayerType.Input)) {
            (uint8 _t, uint[3] memory ipd) = abi.decode(slc.conf, (uint8, uint[3]));
            models[modelId].inputDim = ipd;
            dim = ipd[0] * ipd[1] * ipd[2];
        }

        return (slc.ptr, dim);
    }

    function loadPerceptron(uint256 modelId, bytes[] memory layersConfig, SD59x18[] calldata weights) internal {
        uint ptr = 0;
        uint dim = 0;
        for (uint i = 0; i < layersConfig.length; i++) {
            (ptr, dim) = makeLayer(modelId, SingleLayerConfig(layersConfig[i], i, dim, ptr), weights);
        }
    }
}


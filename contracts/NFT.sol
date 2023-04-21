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
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./Layers.sol";

error NotTokenOwner();
error InsufficientMintPrice();

contract Perceptrons is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable {
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Tensors for Tensors.Tensor;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    mapping(uint => Model) public models;
    uint public mintPrice;

    struct Model {
        uint inputDim;
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

    enum LayerType {
        Dense,
        Flatten,
        Rescale
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

    function getInfo(uint256 modelId) public view returns (uint, SD59x18[][][] memory, uint[] memory, string memory, string[] memory) {
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

    function safeMint(address to, string memory uri, string memory modelName, string[] memory classesName) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();
        uint256 modelId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
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
        // if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();

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

    function loadWeights(uint256 modelId, bytes[] memory layers_config, SD59x18[] memory weights) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();

        uint ipd = loadPerceptron(modelId, layers_config, weights);
        models[modelId].inputDim = ipd;
    }

    function makeLayer(uint256 modelId, bytes memory conf, uint ind) internal {
        bytes memory temp = new bytes(1);
        temp[0] = conf[0];
        uint8 layerType = abi.decode(temp, (uint8));
        
        if (layerType == uint8(LayerType.Dense)) {
            (uint8 t1, uint8 actv, uint d, SD59x18[][] memory w, SD59x18[] memory b) = abi.decode(conf, (uint8, uint8, uint, SD59x18[][], SD59x18[]));
            Layers.DenseLayer memory layer = Layers.DenseLayer(ind, Layers.ActivationFunc(actv), d, w, b);
            models[modelId].d.push(layer);
        } else if (layerType == uint8(LayerType.Flatten)) {
            Layers.FlattenLayer memory layer = Layers.FlattenLayer(ind);
            models[modelId].f.push(layer);
        } else if (layerType == uint8(LayerType.Rescale)) {
            (uint8 t1, SD59x18 scale, SD59x18 offset) = abi.decode(conf, (uint8, SD59x18, SD59x18));
            Layers.RescaleLayer memory layer = Layers.RescaleLayer(ind, scale, offset);
            models[modelId].r.push(layer);
        }
    }

    function loadPerceptron(uint256 modelId, bytes[] memory layersConfig, SD59x18[] memory weights) internal pure returns (uint) {

        uint dim = 0;
        uint p = 0;
        uint ipd = 0;
        // for (uint i = 0; i < layersConfig.length; i++) {
        //  if (layersConfig[i] == 0) {
        //      dim = layersConfig[i + 1];
        //      ipd = dim;
        //  } else if (layersConfig[i] == 1) {
        //      preprocessLayers.push(Layers.RescaleLayer(layersConfig[i + 1], layersConfig[i + 2]));
        //  } else if (layersConfig[i] == 2) {
        //      // dim = [dim.reduce((a, b) => a * b)];
        //      // solidity:
        //      dim = 1;
        //      for (uint j = 0; j < layersConfig[i + 1]; j++) {
        //          dim *= layersConfig[i + 2 + j];
        //      }
        //  } else if (layersConfig[i] == 3) {
        //      uint nxt_dim = [layersConfig[i + 1]];
        //      uint w_size = dim[0] * nxt_dim[0];
        //      uint b_size = nxt_dim[0];

                // uint[] memory w_array = weights.subarray(p, p + w_size);
                // p += w_size;
                // uint[] memory b_array = weights.subarray(p, p + b_size);
                // p += b_size;

                // Tensors.Tensor memory w_tensor;
                // w_tensor.load(w_array, dim[0], nxt_dim[0]);
                // Tensors.Tensor memory b_tensor;
                // b_tensor.load(b_array, 1, nxt_dim[0]);

                // hiddenLayers.push(Layers.DenseLayer(nxt_dim[0], w_tensor, b_tensor));
        //      dim = nxt_dim;
        //  }
        // }

        // Layers.DenseLayer memory outputLayer = hiddenLayers.pop();

        return ipd;
    }
}

// contract Example is ERC721, ERC721URIStorage, AccessControl {
//     using Counters for Counters.Counter;

//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     Counters.Counter private _tokenIdCounter;

//     constructor() ERC721("Perceptrons", "PCT") {
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(MINTER_ROLE, msg.sender);
//     }

//     function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) {
//         uint256 modelId = _tokenIdCounter.current();
//         _tokenIdCounter.increment();
//         _safeMint(to, modelId);
//         _setTokenURI(modelId, uri);
//     }

//     function batchMint(address[] memory to, string[] memory uri) public onlyRole(MINTER_ROLE) {
//         if (to.length != uri.length) revert InvalidArrayLength();
//         for (uint256 i = 0; i < to.length; i++) {
//             safeMint(to[i], uri[i]);
//         }
//     }


//     // The following functions are overrides required by Solidity.

//     function _burn(uint256 modelId) internal override(ERC721, ERC721URIStorage) {
//         super._burn(modelId);
//     }

//     function tokenURI(uint256 modelId)
//         public
//         view
//         override(ERC721, ERC721URIStorage)
//         returns (string memory)
//     {
//         return super.tokenURI(modelId);
//     }

//     function supportsInterface(bytes4 interfaceId)
//         public
//         view
//         override(ERC721, AccessControl)
//         returns (bool)
//     {
//         return super.supportsInterface(interfaceId);
//     }
// }


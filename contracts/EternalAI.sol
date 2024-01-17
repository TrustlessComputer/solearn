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
import "./lib/Layers.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();

contract EternalAI is
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
    using Tensor2DMethods for Tensors.Tensor2D;
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
        SD59x18[][][][] outputs1,
        SD59x18[][] outputs2
    );

    struct Model {
        uint256[3] inputDim;
        string modelName;
        string[] classesName;
        uint256 numLayers;
        Layers.RescaleLayer[] r;
        Layers.FlattenLayer[] f;
        Layers.DenseLayer[] d;
        Layers.MaxPooling2DLayer[] mp2;
        Layers.Conv2DLayer[] c2;
        Info[] layers;
    }

    struct Info {
        LayerType layerType;
        uint256 layerIndex;
    }

    struct SingleLayerConfig {
        bytes conf;
        uint256 ind;
        uint256[3] prevDim1;
        uint256 prevDim2;
    }

    enum LayerType {
        Dense,
        Flatten,
        Rescale,
        Input,
        MaxPooling2D,
        Conv2D
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
        __ERC721_init("EternalAI", "EAI");
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
            string memory,
            string[] memory,
            Info[] memory
        )
    {
        Model storage m = models[modelId];
        return (
            models[modelId].inputDim,
            models[modelId].modelName,
            models[modelId].classesName,
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
        Layers.Conv2DLayer memory layer = models[modelId].c2[layerIdx];
        n = layer.w.n;
        m = layer.w.m;
        p = layer.w.p;
        q = layer.w.q;
        w = layer.w.mat;
        b = layer.b.mat;
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
        SD59x18[][][][] memory x1,
        SD59x18[][] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (
        SD59x18[][][][] memory,
        SD59x18[][] memory
    ) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            // console.log(i);
            Info memory layerInfo = models[modelId].layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Rescale) {
                x1 = models[modelId].r[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Flatten) {
                x2 = models[modelId].f[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2 = models[modelId].d[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == LayerType.MaxPooling2D) {
                x1 = models[modelId].mp2[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Conv2D) {
                x1 = models[modelId].c2[layerInfo.layerIndex].forward(x1);
            }

            // the last layer
            if (i == models[modelId].layers.length - 1) {
                Tensors.Tensor2D memory xt = Tensor2DMethods.from(x2);
                SD59x18[][] memory result = new SD59x18[][](1);
                result[0] = Tensor2DMethods.flat(xt.softmax().mat);
                return (x1, result);
            }
        }

        return (x1, x2);
    }

    function evaluate(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][][] calldata x1,
        SD59x18[][] calldata x2 
    ) public view returns (string memory, SD59x18[][][][] memory, SD59x18[][] memory) {
        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        (SD59x18[][][][] memory r1, SD59x18[][] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2[0].length; i++) {
                if (r2[0][i].gt(r2[0][maxInd])) {
                    maxInd = i;
                }
            }

            return (models[modelId].classesName[maxInd], r1, r2);
        } else {
            return ("", r1, r2);
        }
    }

    function classify(
        uint256 modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][][] calldata x1,
        SD59x18[][] calldata x2
    ) external payable {
        if (msg.value < evalPrice) revert InsufficientEvalPrice();

        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        (SD59x18[][][][] memory r1, SD59x18[][] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2[0].length; i++) {
                if (r2[0][i].gt(r2[0][maxInd])) {
                    maxInd = i;
                }
            }

            emit Classified(
                modelId,
                maxInd,
                models[modelId].classesName[maxInd],
                r2[0]
            );
        } else {
            emit Forwarded(modelId, fromLayerIndex, toLayerIndex, r1, r2);
        }

        uint256 protocolFee = (msg.value * protocolFeePercent) / 100;
        uint256 royalty = msg.value - protocolFee;
        (bool success, ) = address(ownerOf(modelId)).call{value: royalty}("");
        if (!success) revert TransferFailed();
    }

    function setEternalAI(
        uint256 modelId,
        bytes[] calldata layers_config
    ) external {
        if (msg.sender != ownerOf(modelId)) revert NotTokenOwner();

        if (models[modelId].numLayers > 0) {
            models[modelId].numLayers = 0;
            delete models[modelId].d;
            delete models[modelId].f;
            delete models[modelId].r;
            delete models[modelId].c2;
            delete models[modelId].mp2;
            delete models[modelId].layers;
        }

        loadEternalAI(modelId, layers_config);
    }

    function appendWeights(
        uint256 modelId,
        SD59x18[] memory weights,
        uint256 layerInd,
        LayerType layerType
    ) external {
        if (layerType == LayerType.Dense) {
            models[modelId].d[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Conv2D) {
            models[modelId].c2[layerInd].appendWeights(weights);
        }
    }

    function makeLayer(
        uint256 modelId,
        SingleLayerConfig memory slc
    ) internal returns (uint256[3] memory, uint256) {
        uint8 layerType = abi.decode(slc.conf, (uint8));
        uint256[3] memory dim1 = slc.prevDim1;
        uint256 dim2 = slc.prevDim2;

        // add more layers
        if (layerType == uint8(LayerType.Dense)) {
            (, uint8 actv, uint256 d) = abi.decode(
                slc.conf,
                (uint8, uint8, uint256)
            );
            models[modelId].d.push(Layers.DenseLayer(
                slc.ind,
                Tensors.ActivationFunc(actv),
                d,
                Tensor2DMethods.emptyTensor(dim2, d),
                Tensor1DMethods.emptyTensor(d),
                0,
                0
            ));
            uint256 index = models[modelId].d.length - 1;
            models[modelId].layers.push(Info(LayerType.Dense, index));

            dim2 = d;
        } else if (layerType == uint8(LayerType.Flatten)) {
            models[modelId].f.push(Layers.FlattenLayer(
                slc.ind
            ));
            dim2 = dim1[0] * dim1[1] * dim1[2];

            uint256 index = models[modelId].f.length - 1;
            models[modelId].layers.push(Info(LayerType.Flatten, index));
        } else if (layerType == uint8(LayerType.Rescale)) {
            (, SD59x18 scale, SD59x18 offset) = abi.decode(
                slc.conf,
                (uint8, SD59x18, SD59x18)
            );
            models[modelId].r.push(Layers.RescaleLayer(
                slc.ind,
                scale,
                offset
            ));

            uint256 index = models[modelId].r.length - 1;
            models[modelId].layers.push(Info(LayerType.Rescale, index));
        } else if (layerType == uint8(LayerType.Input)) {
            (, uint256[3] memory ipd) = abi.decode(
                slc.conf,
                (uint8, uint256[3])
            );
            models[modelId].inputDim = ipd;
            dim1 = ipd;

            // TODO: have only one layer type input ?
            Info memory layerInfo = Info(LayerType.Input, 0);
            models[modelId].layers.push(layerInfo);
        } else if (layerType == uint8(LayerType.MaxPooling2D)) {
            (, uint256[2] memory size, uint256[2] memory stride, uint8 padding) = abi.decode(
                slc.conf,
                (uint8, uint256[2], uint256[2], uint8)
            );
            models[modelId].mp2.push(Layers.MaxPooling2DLayer(
                slc.ind,
                size,
                stride,
                Tensors.PaddingType(padding)
            ));
            uint256 index = models[modelId].mp2.length - 1;
            models[modelId].layers.push(Info(LayerType.MaxPooling2D, index));

            uint256[2] memory out;
            (out, ) = Tensors.getConvSize(
                [dim1[0], dim1[1]],
                size,
                stride,
                Tensors.PaddingType(padding)
            );
            dim1[0] = out[0];
            dim1[1] = out[1];
        } else if (layerType == uint8(LayerType.Conv2D)) {
            (, uint8 actv, uint256 filters, uint256[2] memory size, uint256[2] memory stride, uint8 padding) = abi.decode(
                slc.conf,
                (uint8, uint8, uint256, uint256[2], uint256[2], uint8)
            );
            models[modelId].c2.push(Layers.Conv2DLayer(
                slc.ind,
                Tensors.ActivationFunc(actv),
                filters,
                stride,
                Tensors.PaddingType(padding),
                Tensor4DMethods.emptyTensor(size[0], size[1], dim1[2], filters),
                Tensor1DMethods.emptyTensor(filters),
                0,
                0
            ));
            uint256 index = models[modelId].c2.length - 1;
            models[modelId].layers.push(Info(LayerType.Conv2D, index));

            uint256[2] memory out;
            (out, ) = Tensors.getConvSize(
                [dim1[0], dim1[1]],
                size,
                stride,
                Tensors.PaddingType(padding)
            );
            dim1[0] = out[0];
            dim1[1] = out[1];
            dim1[2] = filters;
        }
        return (dim1, dim2);
    }

    function loadEternalAI(
        uint256 modelId,
        bytes[] calldata layersConfig
    ) internal {
        models[modelId].numLayers = layersConfig.length;
        uint256[3] memory dim1;
        uint256 dim2;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            (dim1, dim2) = makeLayer(
                modelId,
                SingleLayerConfig(layersConfig[i], i, dim1, dim2)
            );
        }
    }

    function testMul(uint256 n) external {
        SD59x18 res = sd(1 * 1e18);
        for(uint i = 0; i < n; ++i) {
            res = res * sd(1.01 * 1e18);
        }
    }

    function testAdd(uint256 n) external {
        SD59x18 res = sd(0);
        for(uint i = 0; i < n; ++i) {
            res = res + sd(1.01 * 1e18);
        }
    }

    function testAddInt256(uint256 n) external {
        int res = 0;
        for(uint i = 0; i < n; ++i) {
            res = res + 12314;
        }
    }

    function testForLoop(uint256 n) external {
        for(uint i = 0; i < n; ++i) {
            
        }
    }
}

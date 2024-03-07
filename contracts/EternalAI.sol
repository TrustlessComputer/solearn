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
import "./thirdparty/solidity-stringutils/strings.sol";
import "./lib/layers/Layers.sol";
import "./lib/Utils.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error UnknownTokenNotInVocabs();

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
    using Layers for Layers.EmbeddingLayer;
    using Layers for Layers.SimpleRNNLayer;
    using Layers for Layers.LSTM;
    using Tensor1DMethods for Tensors.Tensor1D;
    using Tensor2DMethods for Tensors.Tensor2D;
    using Tensor3DMethods for Tensors.Tensor3D;
    using Tensor4DMethods for Tensors.Tensor4D;
    using Strings for *;

    mapping(uint256 => Model) public models;
    mapping(uint256 => VocabInfo) public vocabInfos;
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
        __ERC721_init("EternalAI", "EAI");
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

    function getLSTMLayer(
        uint256 modelId,
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256,
            uint256,
            SD59x18[][] memory,
            SD59x18[][] memory,
            SD59x18[] memory
        )
    {
        Layers.LSTM memory layer = models[modelId].lstm[layerIdx];
        Layers.LSTMCell memory cell = layer.cell;
        uint256 inputUnits = layer.inputUnits;
        uint256 units = cell.units;
        return (
            inputUnits,
            units,
            cell.kernel_f.mat,
            cell.recurrentKernel_f.mat,
            cell.bias_f.mat
        );
    }

    function safeMint(
        address to,
        uint256 modelId,
        string memory uri,
        string memory modelName,
        string[] memory classesName
    ) external payable {
        // NOTE: TODO uncomment for mainnet
        // if (msg.value < mintPrice) revert InsufficientMintPrice();

        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        models[modelId].modelName = modelName;
        for (uint256 i = 0; i < classesName.length; i++) {
            models[modelId].classesName.push(classesName[i]);
        }
    }

    function forward(
        uint256 modelId,
        SD59x18[][][] memory x1,
        SD59x18[] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public view returns (SD59x18[][][] memory, SD59x18[] memory) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
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
        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2.length; i++) {
                if (r2[i].gt(r2[maxInd])) {
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
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    ) external payable {
        // NOTE: TODO uncomment for mainnet
        // if (msg.value < evalPrice) revert InsufficientEvalPrice();

        if (toLayerIndex >= models[modelId].layers.length) {
            toLayerIndex = models[modelId].layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
            modelId,
            x1,
            x2,
            fromLayerIndex,
            toLayerIndex
        );

        if (toLayerIndex == models[modelId].layers.length - 1) {
            uint256 maxInd = 0;
            for (uint256 i = 1; i < r2.length; i++) {
                if (r2[i].gt(r2[maxInd])) {
                    maxInd = i;
                }
            }

            emit Classified(
                modelId,
                maxInd,
                models[modelId].classesName[maxInd],
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

    function feedRNN(
        uint256 modelId,
        uint256 inputToken,
        SD59x18[][] memory rnn_state
    ) internal view returns (SD59x18[][] memory nxt_state) {
        Model storage model = models[modelId];
        uint256 x1 = inputToken;
        SD59x18[] memory x2;

        uint nLayers = model.layers.length;
        for (uint256 i = 0; i < nLayers; i++) {
            Info memory layerInfo = model.layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Embedding) {
                x2 = model.embedding[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2 = model.d[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == LayerType.SimpleRNN) {
                (x2, rnn_state) = model.simpleRNN[layerInfo.layerIndex].forward(x2, rnn_state);
            } else if (layerInfo.layerType == LayerType.LSTM) {
                SD59x18[][] memory x2Ext;
                uint256 gasUsed;
                (x2Ext, rnn_state, gasUsed) = model.lstm[layerInfo.layerIndex].forward(x2, rnn_state);
                x2 = x2Ext[0];
            }
        }

        return rnn_state;
    }

    function evaluateRNN(
        uint256 modelId,
        uint256 inputToken,
        SD59x18[][] memory rnn_state,
        uint256 seed
    ) internal view returns (uint256 outputToken, SD59x18[][] memory nxt_state) {
        Model storage model = models[modelId];
        uint256 x1 = inputToken;
        SD59x18[] memory x2;

        uint256 gasUsed;

        uint nLayers = model.layers.length;
        for (uint256 i = 0; i < nLayers; i++) {
            Info memory layerInfo = model.layers[i];

            // add more layers
            if (layerInfo.layerType == LayerType.Embedding) {
                x2 = model.embedding[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                x2 = model.d[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == LayerType.SimpleRNN) {
                (x2, rnn_state) = model.simpleRNN[layerInfo.layerIndex].forward(x2, rnn_state);
            } else if (layerInfo.layerType == LayerType.LSTM) {
                SD59x18[][] memory x2Ext;
                (x2Ext, rnn_state, gasUsed) = model.lstm[layerInfo.layerIndex].forward(x2, rnn_state);
                x2 = x2Ext[0];
            }
        }

        console.log(gasUsed);

        Tensors.Tensor1D memory xt = Tensor1DMethods.from(x2);
        SD59x18[] memory probs = xt.softmax().mat;
        outputToken = Utils.getWeightedRandom(probs, seed);

        return (outputToken, rnn_state);
    }

    function tokenize(uint256 modelId, string memory str) internal view returns (uint256[] memory) {
        Strings.slice memory slice = str.toSlice();
        uint256 len = slice.len();

        VocabInfo storage info = vocabInfos[modelId];
        
        uint256[] memory idxs = new uint256[](len); 
        for(uint256 i = 0; i < len; ++i) {
            string memory token = slice.nextRune().toString();
            bytes32 _hash = Utils.getHash(token);
            uint256 idx = info.hashToIndex[_hash];
            idxs[i] = (idx == 0) ? (info.unkIndex - 1) : (idx - 1);
        }

        return idxs;
    }

    function decodeTokens(uint256 modelId, uint256[] memory tokens) internal view returns (string memory output) {
        VocabInfo storage info = vocabInfos[modelId];
        output = "";
        for(uint i = 0; i < tokens.length; ++i) {
            string memory ch = info.vocabs[tokens[i]];
            output = string.concat(output, ch);
        }
        return output;
    }

    function generateText(
        uint256 modelId,
        string memory prompt,
        uint256 toGenerate,
        uint256 seed,
        SD59x18 temperature
    ) external returns (string memory) {
        uint256[] memory tokens = tokenize(modelId, prompt); 

        SD59x18[][] memory states;
        if (models[modelId].simpleRNN.length > 0) {
            states = Tensor2DMethods.zerosTensor(1, models[modelId].simpleRNN[0].units).mat;
        } else if (models[modelId].lstm.length > 0) {
            states = Tensor2DMethods.zerosTensor(2, models[modelId].lstm[0].cell.units).mat;
        }

        for(uint i = 0; i < tokens.length - 1; ++i) {
            states = feedRNN(modelId, tokens[i], states);
        }

        uint256 lastToken = tokens[tokens.length - 1];
        uint256[] memory generatedTokens = new uint256[](toGenerate);
        
        for(uint i = 0; i < toGenerate; ++i) {
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint256 startGas = gasleft();
            (lastToken, states) = evaluateRNN(modelId, lastToken, states, seed);
            uint256 gasUsed = startGas - gasleft();
            console.log(i, gasUsed);
            generatedTokens[i] = lastToken;
        }

        string memory generatedText = decodeTokens(modelId, generatedTokens);
        return generatedText;
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
            delete models[modelId].embedding;
            delete models[modelId].simpleRNN;
            delete models[modelId].lstm;
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
        uint appendedWeights;
        if (layerType == LayerType.Dense) {
            appendedWeights = models[modelId].d[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Conv2D) {
            appendedWeights = models[modelId].c2[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Embedding) {
            appendedWeights = models[modelId].embedding[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.SimpleRNN) {
            appendedWeights = models[modelId].simpleRNN[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.LSTM) {
            appendedWeights = models[modelId].lstm[layerInd].appendWeightsPartial(weights);
        }
        models[modelId].appendedWeights += appendedWeights;
        if (models[modelId].appendedWeights == models[modelId].requiredWeights) {
            emit Deployed(msg.sender, modelId);
        }
    }

    function setVocabs(
        uint256 modelId,
        string[] memory vocabs,
        string memory unkToken
    ) external {
        VocabInfo storage info = vocabInfos[modelId];
        info.vocabs = vocabs;
        for(uint256 i = 0; i < vocabs.length; ++i) {
            info.hashToIndex[Utils.getHash(vocabs[i])] = i+1;
        }        
        info.unkIndex = info.hashToIndex[Utils.getHash(unkToken)];
        if (!Utils.equals(vocabs[info.unkIndex - 1], unkToken)) {
            revert UnknownTokenNotInVocabs();
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
        } else if (layerType == uint8(LayerType.MaxPooling2D)) {
            (
                Layers.MaxPooling2DLayer memory layer,
                uint[3] memory out_dim1
            ) = Layers.makeMaxPooling2DLayer(slc, dim1);
            models[modelId].mp2.push(layer);
            dim1 = out_dim1;

            uint256 index = models[modelId].mp2.length - 1;
            models[modelId].layers.push(Info(LayerType.MaxPooling2D, index));
        } else if (layerType == uint8(LayerType.Conv2D)) {
            (Layers.Conv2DLayer memory layer, uint[3] memory out_dim1, uint weights) = Layers
                .makeConv2DLayer(slc, dim1);
            models[modelId].c2.push(layer);
            models[modelId].requiredWeights += weights;
            dim1 = out_dim1;

            uint256 index = models[modelId].c2.length - 1;
            models[modelId].layers.push(Info(LayerType.Conv2D, index));
        } else if (layerType == uint8(LayerType.Embedding)) {
            (Layers.EmbeddingLayer memory layer, uint out_dim2, uint weights) = Layers
                .makeEmbeddingLayer(slc);
            models[modelId].embedding.push(layer);
            models[modelId].requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = models[modelId].embedding.length - 1;
            models[modelId].layers.push(Info(LayerType.Embedding, index));
        } else if (layerType == uint8(LayerType.SimpleRNN)) {
            (Layers.SimpleRNNLayer memory layer, uint out_dim2, uint weights) = Layers
                .makeSimpleRNNLayer(slc, dim2);
            models[modelId].simpleRNN.push(layer);
            models[modelId].requiredWeights += weights;
            dim2 = out_dim2;

            uint256 index = models[modelId].simpleRNN.length - 1;
            models[modelId].layers.push(Info(LayerType.SimpleRNN, index));
        } else if (layerType == uint8(LayerType.LSTM)) {
            (Layers.LSTM memory layer, uint out_dim) = Layers
                .makeLSTMLayer(slc, dim2);
            models[modelId].lstm.push(layer);
            dim2 = out_dim;

            uint256 index = models[modelId].lstm.length - 1;
            models[modelId].layers.push(Info(LayerType.LSTM, index));
        }
        return (dim1, dim2);
    }

    function loadEternalAI(
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

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
import "@openzeppelin/contracts/access/Ownable.sol";
import "./thirdparty/solidity-stringutils/strings.sol";
import "./lib/layers/Layers.sol";
import "./lib/Utils.sol";

import {IModel} from "./interfaces/IModel.sol";
import {IModelCollection} from './interfaces/IModelCollection.sol';

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error UnknownTokenNotInVocabs();
error IncorrectModelId();
error NotModelRegistry();

// interface IModelReg is IERC721Upgradeable {
//     function modelAddr(uint256 tokenId) external view returns (address);
//     function evalPrice() external view returns (uint256);
//     function royaltyReceiver() external view returns (address);
// }

contract EternalAI is IModel, Ownable {
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

    Model public model;
    VocabInfo public vocabInfo;
    IModelCollection public modelRegistry;
    uint256 public modelId;
    uint256 version;

    event Classified(
        uint256 indexed tokenId,
        uint256 classIndex,
        string className,
        SD59x18[] outputs,
        SD59x18 confidence
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

    event TextGenerated(
        uint256 indexed tokenId,
        string result,
        SD59x18[][][] states,
        uint256 seed
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

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner() && modelId > 0 && msg.sender != modelRegistry.ownerOf(modelId)) {
            revert NotTokenOwner();
        }
        _;
    }

    modifier onlyMintedModel() {
        if (modelId == 0) {
            revert IncorrectModelId();
        }
        _;
    }

    constructor(string memory _modelName, string[] memory _classesName, address _modelRegistry) Ownable() {
        model.modelName = _modelName;
        model.classesName = _classesName;

        modelRegistry = IModelCollection(_modelRegistry);      
        version = 1;
    }



    // function initialize(string memory _modelName, string[] memory _classesName, address _modelRegistry) public initializer {
    //     __Ownable_init();
    //     model.modelName = _modelName;
    //     model.classesName = _classesName;

    //     modelRegistry = IModelReg(_modelRegistry);      
    //     version = 1;
    // }

    function getInfo(
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
        return (
            model.inputDim,
            model.modelName,
            model.classesName,
            model.layers
        );
    }

    function getDenseLayer(
        uint256 _modelId,
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
        uint256 _modelId,
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

    function getLSTMLayer(
        uint256 _modelId,
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
        Layers.LSTM memory layer = model.lstm[layerIdx];
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

    function forward(
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
        uint256 _modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    )
        public
        view
        onlyMintedModel
        returns (string memory, SD59x18[][][] memory, SD59x18[] memory, SD59x18)
    {
        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
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

            return (model.classesName[maxInd], r1, r2, r2[maxInd]);
        } else {
            return ("", r1, r2, sd(0));
        }
    }

    function classify(
        uint256 _modelId,
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        SD59x18[][][] calldata x1,
        SD59x18[] calldata x2
    ) external payable onlyMintedModel {
        if (msg.value < modelRegistry.evalPrice()) revert InsufficientEvalPrice();
        (bool success, ) = modelRegistry.royaltyReceiver().call{value: msg.value}("");
        if (!success) revert TransferFailed();


        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }

        (SD59x18[][][] memory r1, SD59x18[] memory r2) = forward(
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
                r2,
                r2[maxInd]
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

    function evaluateRNN(
        Model memory model,
        uint256 inputToken,
        SD59x18[][][] memory rnn_state,
        bool isGenerating
    ) internal view returns (SD59x18[] memory, SD59x18[][][] memory) {
        uint256 x1 = inputToken;
        SD59x18[] memory x2;

        uint nLayers = model.layers.length;
        for (uint256 i = 0; i < nLayers; i++) {
            Info memory layerInfo = model.layers[i];
            uint idx = layerInfo.layerIndex;

            // add more layers
            if (layerInfo.layerType == LayerType.Embedding) {
                x2 = model.embedding[idx].forward(x1);
            } else if (layerInfo.layerType == LayerType.Dense) {
                if (i < model.layers.length - 1 || isGenerating) {
                    x2 = model.d[idx].forward(x2);
                }
            } else if (layerInfo.layerType == LayerType.SimpleRNN) {
                (x2, rnn_state[idx]) = model.simpleRNN[idx].forward(x2, rnn_state[idx]);
            } else if (layerInfo.layerType == LayerType.LSTM) {
                if (x2.length == 0) {
                    x2 = new SD59x18[](1);
                    x2[0] = sd(int(x1 * 1e18 / vocabInfo.vocabs.length));
                }

                SD59x18[][] memory x2Ext;
                (x2Ext, rnn_state[idx]) = model.lstm[idx].forward(x2, rnn_state[idx]);
                x2 = x2Ext[0];
            }
        }

        return (x2, rnn_state);
    }

    function tokenize(string memory str) internal view returns (uint256[] memory) {
        Strings.slice memory slice = str.toSlice();
        uint256 len = slice.len();

        VocabInfo storage info = vocabInfo;
        
        uint256[] memory idxs = new uint256[](len); 
        for(uint256 i = 0; i < len; ++i) {
            string memory token = slice.nextRune().toString();
            bytes32 _hash = Utils.getHash(token);
            uint256 idx = info.hashToIndex[_hash];
            idxs[i] = (idx == 0) ? (info.unkIndex - 1) : (idx - 1);
        }

        return idxs;
    }

    function decodeTokens(uint256[] memory tokens) internal view returns (string memory output) {
        VocabInfo storage info = vocabInfo;
        output = "";
        for(uint i = 0; i < tokens.length; ++i) {
            string memory ch = info.vocabs[tokens[i]];
            output = string.concat(output, ch);
        }
        return output;
    }

    function getToken(
        SD59x18[] memory x2,
        SD59x18 temperature,
        uint256 seed 
    ) internal view returns (uint256) {
        uint unkIndex = vocabInfo.unkIndex - 1;

        SD59x18[] memory tmp = Utils.clone(x2);
        tmp[unkIndex] = tmp[unkIndex] - sd(1e18 * 1e18);
        for(uint i = 0; i < tmp.length; ++i) {
            tmp[i] = tmp[i] / temperature;
        }

        Tensors.Tensor1D memory xt = Tensor1DMethods.from(tmp);
        SD59x18[] memory probs = xt.softmax().mat;
        uint256 outputToken = Utils.getWeightedRandom(probs, seed);
        return outputToken;
    }

    function generateTextHelper(
        string memory prompt,
        uint256 toGenerate,
        SD59x18[][][] memory states,
        uint256 seed
    ) internal view returns (string memory, SD59x18[][][] memory, uint256) {
        SD59x18 temperature = sd(7e17);

        Model memory model = model;

        uint256[] memory tokens = tokenize(prompt); 

        SD59x18[] memory x2;
        if (states.length == 0) {
            if (model.simpleRNN.length > 0) {
                states = Tensor3DMethods.zerosTensor(model.simpleRNN.length, 1, model.simpleRNN[0].units).mat;
            } else if (model.lstm.length > 0) {
                states = Tensor3DMethods.zerosTensor(model.lstm.length, 2, model.lstm[0].cell.units).mat;
            }
            for(uint i = 0; i < tokens.length - 1; ++i) {
                (x2, states) = evaluateRNN(model, tokens[i], states, false);
            }
        }

        uint256 lastToken = tokens[tokens.length - 1];
        uint256[] memory generatedTokens = new uint256[](toGenerate);
        
        for(uint i = 0; i < toGenerate; ++i) {
            seed = uint256(keccak256(abi.encodePacked(seed)));
            (x2, states) = evaluateRNN(model, lastToken, states, true);
            lastToken = getToken(x2, temperature, seed);
            generatedTokens[i] = lastToken;
        }
        string memory generatedText = decodeTokens(generatedTokens);
        return (generatedText, states, seed); 
    } 

    function generateTextNoTx(
        uint _modelId,
        string memory prompt,
        uint256 toGenerate,
        SD59x18[][][] memory states,
        uint256 seed
    ) external view onlyMintedModel returns (string memory, SD59x18[][][] memory, uint256) {
        return generateTextHelper(prompt, toGenerate, states, seed); 
    }

    function generateText(
        uint _modelId,
        string memory prompt,
        uint256 toGenerate,
        SD59x18[][][] memory states,
        uint256 seed
    ) external onlyMintedModel {
        string memory generatedText;
        (generatedText, states, seed) = generateTextHelper(prompt, toGenerate, states, seed);
        emit TextGenerated(modelId, generatedText, states, seed); 
    }

    function setEternalAI(
        uint256 _modelId,
        bytes[] calldata layers_config
    ) external onlyOwnerOrOperator {

        if (model.numLayers > 0) {
            model.numLayers = 0;
            delete model.d;
            delete model.f;
            delete model.r;
            delete model.c2;
            delete model.mp2;
            delete model.embedding;
            delete model.simpleRNN;
            delete model.lstm;
            delete model.layers;
        }

        loadEternalAI(layers_config);
    }

    function setModelId(uint256 _modelId) external {
        if (msg.sender != address(modelRegistry)) {
            revert NotModelRegistry();
        }
        if (modelId > 0 || modelRegistry.modelAddr(_modelId) != address(this)) {
            revert IncorrectModelId();
        }

        modelId = _modelId;
        if (model.appendedWeights == model.requiredWeights && modelId > 0) {
            emit Deployed(modelRegistry.ownerOf(modelId), modelId);
        }
    }

    function appendWeights(
        uint256 _modelId,
        SD59x18[] memory weights,
        uint256 layerInd,
        LayerType layerType
    ) external onlyOwnerOrOperator {
        uint appendedWeights;
        if (layerType == LayerType.Dense) {
            appendedWeights = model.d[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Conv2D) {
            appendedWeights = model.c2[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.Embedding) {
            appendedWeights = model.embedding[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.SimpleRNN) {
            appendedWeights = model.simpleRNN[layerInd].appendWeights(weights);
        } else if (layerType == LayerType.LSTM) {
            appendedWeights = model.lstm[layerInd].appendWeightsPartial(weights);
        }
        model.appendedWeights += appendedWeights;
        if (model.appendedWeights == model.requiredWeights && _modelId > 0) {
            emit Deployed(modelRegistry.ownerOf(modelId), _modelId);
        }
    }

    function setVocabs(
        uint256 _modelId,
        string[] memory vocabs,
        string memory unkToken
    ) external onlyOwnerOrOperator {
        VocabInfo storage info = vocabInfo;
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
        } else if (layerType == uint8(LayerType.LSTM)) {
            (Layers.LSTM memory layer, uint out_dim, uint weights) = Layers
                .makeLSTMLayer(slc, dim2);
            model.lstm.push(layer);
            model.requiredWeights += weights;
            dim2 = out_dim;

            uint256 index = model.lstm.length - 1;
            model.layers.push(Info(LayerType.LSTM, index));
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

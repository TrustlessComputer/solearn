// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./thirdparty/solidity-stringutils/strings.sol";
import "./lib/layers/Layers.sol";
import "./lib/Utils.sol";
import { IModelRegPublic } from "./interfaces/IModelReg.sol";
import { ITextRNN } from "./interfaces/ITextRNN.sol";
// import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error UnknownTokenNotInVocabs();
error IncorrectModelId();
error NotModelRegistry();
error IncorrectInputLayerType();

contract TextRNN is ITextRNN, Ownable {
    using Layers for Layers.DenseLayer;
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
    IModelRegPublic public modelRegistry;
    uint256 public modelId;
    uint256 version;

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

    constructor(string memory _modelName, address _modelRegistry) Ownable() {
        model.modelName = _modelName;
        modelRegistry = IModelRegPublic(_modelRegistry);      
        version = 1;
    }

    function getInfo()
        public
        view
        returns (
            string memory modelName,
            string[] memory vocabs,
            Info[] memory layers
        )
    {
        return (
            model.modelName,
            vocabInfo.vocabs,
            model.layers
        );
    }

    function getDenseLayer(
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256 dim_in,
            uint256 dim_out,
            Float32x32[][] memory w,
            Float32x32[] memory b
        )
    {
        Layers.DenseLayer memory layer = model.dense[layerIdx];
        dim_in = layer.w.n;
        dim_out = layer.w.m;
        w = layer.w.mat;
        b = layer.b.mat;
    }

    function getLSTMLayer(
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256,
            uint256,
            Float32x32[][] memory,
            Float32x32[][] memory,
            Float32x32[] memory
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

    function evaluateRNN(
        Model memory model,
        uint256 inputToken,
        Float32x32[][][] memory rnn_state,
        bool isGenerating
    ) internal returns (Float32x32[] memory, Float32x32[][][] memory) {
        uint256 x1 = inputToken;
        Float32x32[] memory x2;

        uint nLayers = model.layers.length;
        for (uint256 i = 0; i < nLayers; i++) {
            // console.log("layer: ", i);
            // for(uint256 j = 0; j < x2.length; ++j) {
            //     console.logInt(Float32x32.unwrap(x2[j]));
            // }
            Info memory layerInfo = model.layers[i];
            uint idx = layerInfo.layerIndex;

            // add more layers
            if (layerInfo.layerType == Layers.LayerType.Embedding) {
                x2 = model.embedding[idx].forward(x1);
            } else if (layerInfo.layerType == Layers.LayerType.Dense) {
                if (i < model.layers.length - 1 || isGenerating) {
                    x2 = model.dense[idx].forward(x2);
                }
            } else if (layerInfo.layerType == Layers.LayerType.SimpleRNN) {
                (x2, rnn_state[idx]) = model.simpleRNN[idx].forward(x2, rnn_state[idx]);
            } else if (layerInfo.layerType == Layers.LayerType.LSTM) {
                if (x2.length == 0) {
                    x2 = new Float32x32[](1);
                    x2[0] = Float32x32.wrap(int64(int((x1 << 32) / vocabInfo.vocabs.length)));
                }

                Float32x32[][] memory x2Ext;
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
        Float32x32[] memory x2,
        Float32x32 temperature,
        uint256 seed 
    ) internal returns (uint256) {
        uint unkIndex = vocabInfo.unkIndex - 1;

        Float32x32[] memory tmp = Utils.clone(x2);
        tmp[unkIndex] = tmp[unkIndex] - fromInt(1e3);
        for(uint i = 0; i < tmp.length; ++i) {
            tmp[i] = tmp[i] / temperature;
        }

        Tensors.Tensor1D memory xt = Tensor1DMethods.from(tmp);
        Float32x32[] memory probs = xt.softmax().mat;
        uint256 outputToken = Utils.getWeightedRandom(probs, seed);
        return outputToken;
    }

    function generateTextHelper(
        string memory prompt,
        uint256 toGenerate,
        Float32x32[][][] memory states,
        uint256 seed
    ) internal returns (string memory, Float32x32[][][] memory, uint256) {
        Float32x32 temperature = Float32x32.wrap(3006477107); // 0.7

        Model memory model = model;

        uint256[] memory tokens = tokenize(prompt); 

        Float32x32[] memory x2;
        if (states.length == 0) {
            if (model.simpleRNN.length > 0) {
                states = Tensor3DMethods.zerosTensor(model.simpleRNN.length, 1, model.simpleRNN[0].units).mat;
            } else if (model.lstm.length > 0) {
                states = Tensor3DMethods.zerosTensor(model.lstm.length, 2, model.lstm[0].cell.units).mat;
            }
        }
        for(uint i = 0; i < tokens.length - 1; ++i) {
            (x2, states) = evaluateRNN(model, tokens[i], states, false);
        }

        uint256 lastToken = tokens[tokens.length - 1];
        uint256[] memory generatedTokens = new uint256[](toGenerate);
        
        for(uint i = 0; i < toGenerate; ++i) {
            seed = uint256(keccak256(abi.encodePacked(seed)));
            // console.log("i: ", i, lastToken);
            (x2, states) = evaluateRNN(model, lastToken, states, true);
            // console.log("Done forward");
            // for(uint256 j = 0; j < x2.length; ++j) {
            //     console.logInt(Float32x32.unwrap(x2[j]));
            // }
            lastToken = getToken(x2, temperature, seed);
            generatedTokens[i] = lastToken;
        }
        string memory generatedText = decodeTokens(generatedTokens);
        return (generatedText, states, seed); 
    } 

    function generateText(
        string memory prompt,
        uint256 toGenerate,
        Float32x32[][][] memory states,
        uint256 seed
    ) external onlyMintedModel {
        string memory generatedText;
        (generatedText, states, seed) = generateTextHelper(prompt, toGenerate, states, seed);
        emit TextGenerated(modelId, generatedText, states, seed); 
    }

    function setOnchainModel(
        bytes[] calldata layersConfig
    ) external onlyOwnerOrOperator {
        if (model.layers.length > 0) {
            delete model.input;
            delete model.dense;
            delete model.embedding;
            delete model.simpleRNN;
            delete model.lstm;
            delete model.layers;
        }

        model.requiredWeights = 0;
        model.appendedWeights = 0;
        uint256[] memory dim;
        for (uint256 i = 0; i < layersConfig.length; i++) {
            dim = makeLayer(
                Layers.SingleLayerConfig(layersConfig[i], i),
                dim
            );
        }
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
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external onlyOwnerOrOperator {
        uint appendedWeights;
        if (layerType == Layers.LayerType.Dense) {
            appendedWeights = model.dense[layerInd].appendWeights(weights);
        } else if (layerType == Layers.LayerType.Embedding) {
            appendedWeights = model.embedding[layerInd].appendWeights(weights);
        } else if (layerType == Layers.LayerType.SimpleRNN) {
            appendedWeights = model.simpleRNN[layerInd].appendWeights(weights);
        } else if (layerType == Layers.LayerType.LSTM) {
            appendedWeights = model.lstm[layerInd].appendWeightsPartial(weights);
        }

        model.appendedWeights += appendedWeights;
    }

    function setVocabs(
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
        uint256[] memory dim
    ) internal returns (uint256[] memory) {
        uint8 layerType = abi.decode(slc.conf, (uint8));

        // add more layers
        if (layerType == uint8(Layers.LayerType.Input)) {
            (, uint8 inputType) = abi.decode(slc.conf, (uint8, uint8));
            if (inputType != uint8(Layers.InputType.Token)) {
                revert IncorrectInputLayerType();
            }
            (Layers.InputTokenLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputTokenLayer(slc);
            model.input.push(layer);
            model.layers.push(Info(Layers.LayerType.Input, model.input.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.Dense)) {
            (Layers.DenseLayer memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeDenseLayer(slc, dim);
            model.dense.push(layer);
            model.requiredWeights += weights;
            model.layers.push(Info(Layers.LayerType.Dense, model.dense.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.Embedding)) {
            (Layers.EmbeddingLayer memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeEmbeddingLayer(slc);
            model.embedding.push(layer);
            model.requiredWeights += weights;
            dim = out_dim;

            uint256 index = model.embedding.length - 1;
            model.layers.push(Info(Layers.LayerType.Embedding, index));
        } else if (layerType == uint8(Layers.LayerType.SimpleRNN)) {
            (Layers.SimpleRNNLayer memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeSimpleRNNLayer(slc, dim);
            model.simpleRNN.push(layer);
            model.requiredWeights += weights;
            dim = out_dim;

            uint256 index = model.simpleRNN.length - 1;
            model.layers.push(Info(Layers.LayerType.SimpleRNN, index));
        } else if (layerType == uint8(Layers.LayerType.LSTM)) {
            (Layers.LSTM memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeLSTMLayer(slc, dim);
            model.lstm.push(layer);
            model.requiredWeights += weights;
            dim = out_dim;

            uint256 index = model.lstm.length - 1;
            model.layers.push(Info(Layers.LayerType.LSTM, index));
        }
        return dim;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/layers/Layers.sol";
import './lib/Utils.sol';
import { IModelRegPublic } from "./interfaces/IModelReg.sol";
import { IMelodyRNN } from "./interfaces/IMelodyRNN.sol";
// import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientEvalPrice();
error TransferFailed();
error InvalidOutput();
error InvalidInput();
error IncorrectModelId();
error NotModelRegistry();
error IncorrectInputLayerType();

contract MelodyRNN is IMelodyRNN, Ownable {
    using Layers for Layers.DenseLayer;
    using Layers for Layers.EmbeddingLayer;
    using Layers for Layers.LSTM;
    using Tensor1DMethods for Tensors.Tensor1D;
    using Tensor2DMethods for Tensors.Tensor2D;
    using Tensor3DMethods for Tensors.Tensor3D;
    using Tensor4DMethods for Tensors.Tensor4D;
    uint256 constant VOCAB_SIZE = 130;

    Model public model;
    address public modelInterface;
    VocabInfo public vocabInfo;

    function getInfo()
        public
        view
        returns (
            string memory modelName,
            uint256[] memory vocabs,
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

    function forward(
        Model memory model,
        uint256 input,
        Float32x32[][][] memory states,
        bool isGenerating
    ) internal returns (Float32x32[] memory, Float32x32[][][] memory) {
        Float32x32[] memory x2;
        Float32x32[][] memory x2Ext;
        for (uint256 i = 0; i < model.layers.length; i++) {
            Info memory layerInfo = model.layers[i];
            if (layerInfo.layerType == Layers.LayerType.Embedding) {
                x2 = model.embedding[layerInfo.layerIndex].forward(input);
            } else if (layerInfo.layerType == Layers.LayerType.Dense) {
                if (i < model.layers.length - 1 || isGenerating) {
                    x2 = model.dense[layerInfo.layerIndex].forward(x2);
                }                
            } else if (layerInfo.layerType == Layers.LayerType.LSTM) {
                if (x2.length == 0) {
                    x2 = new Float32x32[](1);
                    x2[0] = Float32x32.wrap(int64(int((input << 32) / VOCAB_SIZE)));
                }

                Layers.LSTM memory lstm = model.lstm[layerInfo.layerIndex];
                (x2Ext, states[layerInfo.layerIndex]) = lstm.forward(x2, states[layerInfo.layerIndex]);
                x2 = x2Ext[0];
            }
        }
        return (x2, states);
    }

    function decodeTokens(Float32x32[] memory tokens) internal view returns (Float32x32[] memory) {
        VocabInfo storage info = vocabInfo;
        for(uint i = 0; i < tokens.length; ++i) {
            uint64 id = uint64(toInt(tokens[i]));
            tokens[i] = fromInt(int(info.vocabs[id]));
        }
        return tokens;
    }

    function getVocabs() public view returns (uint256[] memory) {
        return vocabInfo.vocabs;
    }

    function getToken(
        Float32x32[] memory x2,
        Float32x32 temperature,
        uint256 seed 
    ) internal view returns (uint256) {
        Float32x32[] memory tmp = Utils.clone(x2);
        for(uint i = 0; i < tmp.length; ++i) {
            tmp[i] = tmp[i] / temperature;
        }

        Tensors.Tensor1D memory xt = Tensor1DMethods.from(tmp);
        Float32x32[] memory probs = xt.softmax().mat;
        uint256 outputToken = Utils.getWeightedRandom(probs, seed);

        return outputToken;
    }

    function generateMelody(
        uint256 noteCount,
        Float32x32[] memory x
    ) internal returns (Float32x32[] memory) {
        Model memory model = model;
        uint256 seed = uint256(keccak256(abi.encodePacked(x)));

        Float32x32 temperature = Float32x32.wrap(1 << 32); // 1.0
        Float32x32[] memory r2;
        Float32x32[][][] memory states = new Float32x32[][][](model.lstm.length);
        for (uint256 i=0; i<x.length-1; i++) {
            (r2, states) = forward(model, uint(int(toInt(x[i]))), states, false);
        }

        Float32x32[] memory result = new Float32x32[](noteCount);
        uint256 inputToken = uint(int(toInt(x[x.length - 1])));
        for (uint256 i=0; i<noteCount; i++) {
            (r2, states) = forward(model, inputToken, states, true);
            uint256 nxtToken = getToken(r2, temperature, seed);
            if (vocabInfo.hasVocab) {
                nxtToken = vocabInfo.vocabs[nxtToken];
            }
            result[i] = fromInt(int(nxtToken));
            seed = uint256(keccak256(abi.encodePacked(seed)));
            inputToken = nxtToken;
        }

        return result;
    }

    function infer(bytes calldata _data) external returns (bytes memory) {
        if (msg.sender != modelInterface) revert Unauthorized();

        (
            uint256 noteCount,
            Float32x32[] memory x
        ) = abi.decode(_data, (uint256, Float32x32[]));
        
        Float32x32[] memory result = generateMelody(noteCount, x);
        
        return abi.encode(result);
    }
    
    function setOnchainModel(
        bytes[] calldata layersConfig
    ) external onlyOwner {
        if (model.layers.length > 0) {
            delete model.input;
            delete model.dense;
            delete model.lstm;
            delete model.embedding;
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

    function isReady() external view returns (bool) {
        return model.appendedWeights == model.requiredWeights;
    }

    function appendWeights(
        Float32x32[] memory weights,
        uint256 layerInd,
        Layers.LayerType layerType
    ) external onlyOwner {
        uint appendedWeights;
        if (layerType == Layers.LayerType.Dense) {
            appendedWeights = model.dense[layerInd].appendWeights(weights);
        } else if (layerType == Layers.LayerType.LSTM) {
            appendedWeights = model.lstm[layerInd].appendWeightsPartial(weights);
        } else if (layerType == Layers.LayerType.Embedding) {
            appendedWeights = model.embedding[layerInd].appendWeights(weights);
        }
    }
    
    function setVocabs(
        uint256[] memory vocabs
    ) external onlyOwner {
        VocabInfo storage info = vocabInfo;
        info.vocabs = vocabs;
        info.hasVocab = true;
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

    function setModelInterface(address _interface) external onlyOwner {
        modelInterface = _interface;
    }
}

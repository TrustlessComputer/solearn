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
import { IFunctionalModel } from "./interfaces/IFunctionalModel.sol";
import { IOnchainModel } from "./interfaces/IOnchainModel.sol";
// import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error UnknownTokenNotInVocabs();
error IncorrectModelId();
error NotModelRegistry();
error IncorrectInputLayerType();
error TooMuchData();

contract FunctionalModel is IFunctionalModel, Ownable {
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

    Model public model;
    address public modelInterface;

    function getInfo()
        public
        view
        returns (
            string memory,
            Info[] memory,
            uint
        )
    {
        return (
            model.modelName,
            model.layers,
            model.requiredWeights
        );
    }

    function forward(Float32x32[] memory input) public returns (bytes memory) {

        return x2;
    }

    function infer(bytes calldata _data) external returns (bytes memory) {
        if (msg.sender != modelInterface) revert Unauthorized();

        Float32x32[] memory input = abi.decode(_data, (Float32x32[]));
        bytes memory output = forward(input);
        return output;
    }
    
    function setClassesName(
        string[] memory classesName
    ) external onlyOwner {
        model.classesName = classesName;
    }

    function setOnchainModel(
        bytes[] calldata layersConfig
    ) external onlyOwner {
        if (model.layers.length > 0) {
            delete model.inputScalar;
            delete model.inputTensor1D;
            delete model.inputTensor2D;
            delete model.inputTensor3D;
            delete model.dense;
            delete model.flatten;
            delete model.rescale;
            delete model.conv2D;
            delete model.maxPooling2D;
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

    function isReady() external view returns (bool) {
        return model.appendedWeights == model.requiredWeights;
    }

    function appendWeights(
        Float32x32[] memory weights
    ) external onlyOwner {
        uint idx = 0;
        uint ptrLayer = model.ptrLayer;
        while (idx < weights.length && model.ptrLayer < model.layers.length) {
            Info memory layerInfo = model.layers[ptrLayer];
            Layers.LayerType layerType = layerInfo.layerType;
            uint layerInd = layerInfo.layerIndex;
            if (layerType == Layers.LayerType.Dense) {
                idx = model.dense[layerInd].appendWeights(weights, idx);
            } else if (layerType == Layers.LayerType.Conv2D) {
                idx = model.conv2D[layerInd].appendWeights(weights);
            } else if (layerType == Layers.LayerType.Embedding) {
                idx = model.embedding[layerInd].appendWeights(weights);
            } else if (layerType == Layers.LayerType.SimpleRNN) {
                idx = model.simpleRNN[layerInd].appendWeights(weights);
            } else if (layerType == Layers.LayerType.LSTM) {
                idx = model.lstm[layerInd].appendWeightsPartial(weights);
            }
        }
        if (idx < weights.length) {
            revert TooMuchData();
        }
        model.ptrLayer = ptrLayer;
        model.appendedWeights += weights.length;
    }

    function makeLayer(
        Layers.SingleLayerConfig memory slc,
        uint256[] memory dim
    ) internal returns (uint256[] memory) {
        uint8 layerType = abi.decode(slc.conf, (uint8));
        if (layerType == uint8(Layers.LayerType.InputScalar)) {
            (Layers.InputScalarLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputScalarLayer(slc);
            model.inputScalar.push(layer);
            model.layers.push(Info(Layers.LayerType.InputScalar, model.input.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.InputTensor1D)) {
            (Layers.InputTensor1DLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputTensor1DLayer(slc);
            model.inputTensor1D.push(layer);
            model.layers.push(Info(Layers.LayerType.InputTensor1D, model.input.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.InputTensor2D)) {
            (Layers.InputTensor2DLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputTensor2DLayer(slc);
            model.inputTensor2D.push(layer);
            model.layers.push(Info(Layers.LayerType.InputTensor2D, model.input.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.InputTensor3D)) {
            (Layers.InputTensor3DLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputTensor3DLayer(slc);
            model.inputTensor3D.push(layer);
            model.layers.push(Info(Layers.LayerType.InputTensor3D, model.input.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.Dense)) {
            (Layers.DenseLayer memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeDenseLayer(slc, dim);
            model.dense.push(layer);
            model.requiredWeights += weights;
            model.layers.push(Info(Layers.LayerType.Dense, model.dense.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.Flatten)) {
            (Layers.FlattenLayer memory layer, uint[] memory out_dim) = Layers
                .makeFlattenLayer(slc, dim);
            model.flatten.push(layer);
            model.layers.push(Info(Layers.LayerType.Flatten, model.flatten.length - 1));
            dim = out_dim;
        } else if (layerType == uint8(Layers.LayerType.Rescale)) {
            Layers.RescaleLayer memory layer = Layers.makeRescaleLayer(slc);
            model.rescale.push(layer);

            uint256 index = model.rescale.length - 1;
            model.layers.push(Info(Layers.LayerType.Rescale, index));
        } else if (layerType == uint8(Layers.LayerType.MaxPooling2D)) {
            (Layers.MaxPooling2DLayer memory layer, uint[] memory out_dim) = Layers
                .makeMaxPooling2DLayer(slc, dim);
            model.maxPooling2D.push(layer);
            dim = out_dim;

            uint256 index = model.maxPooling2D.length - 1;
            model.layers.push(Info(Layers.LayerType.MaxPooling2D, index));
        } else if (layerType == uint8(Layers.LayerType.Conv2D)) {
            (Layers.Conv2DLayer memory layer, uint[] memory out_dim, uint weights) = Layers
                .makeConv2DLayer(slc, dim);
            model.conv2D.push(layer);
            model.requiredWeights += weights;
            dim = out_dim;

            uint256 index = model.conv2D.length - 1;
            model.layers.push(Info(Layers.LayerType.Conv2D, index));
        }else if (layerType == uint8(Layers.LayerType.Embedding)) {
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

    function setModelInterface(address _interface) external onlyOwner {
        modelInterface = _interface;
    }
}

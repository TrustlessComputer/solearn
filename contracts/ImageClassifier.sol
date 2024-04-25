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
import { IImageClassifier } from "./interfaces/IImageClassifier.sol";
// import "hardhat/console.sol";

error NotTokenOwner();
error InsufficientMintPrice();
error InsufficientEvalPrice();
error TransferFailed();
error UnknownTokenNotInVocabs();
error IncorrectModelId();
error NotModelRegistry();
error IncorrectInputLayerType();

contract ImageClassifier is IImageClassifier, Ownable {
    using Layers for Layers.RescaleLayer;
    using Layers for Layers.FlattenLayer;
    using Layers for Layers.DenseLayer;
    using Layers for Layers.MaxPooling2DLayer;
    using Layers for Layers.Conv2DLayer;
    using Tensor1DMethods for Tensors.Tensor1D;
    using Tensor2DMethods for Tensors.Tensor2D;
    using Tensor3DMethods for Tensors.Tensor3D;
    using Tensor4DMethods for Tensors.Tensor4D;

    Model public model;
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
            uint256[3] memory,
            string memory,
            string[] memory,
            Info[] memory
        )
    {
        return (
            model.input[0].inputDim,
            model.modelName,
            model.classesName,
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

    function getConv2DLayer(
        uint256 layerIdx
    )
        public
        view
        returns (
            uint256 n,
            uint256 m,
            uint256 p,
            uint256 q,
            Float32x32[][][][] memory w,
            Float32x32[] memory b
        )
    {
        Layers.Conv2DLayer memory layer = model.conv2D[layerIdx];
        n = layer.w.n;
        m = layer.w.m;
        p = layer.w.p;
        q = layer.w.q;
        w = layer.w.mat;
        b = layer.b.mat;
    }

    function forward(
        Float32x32[][][] memory x1,
        Float32x32[] memory x2,
        uint256 fromLayerIndex,
        uint256 toLayerIndex
    ) public returns (Float32x32[][][] memory, Float32x32[] memory) {
        for (uint256 i = fromLayerIndex; i <= toLayerIndex; i++) {
            Info memory layerInfo = model.layers[i];

            // add more layers
            if (layerInfo.layerType == Layers.LayerType.Rescale) {
                x1 = model.rescale[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == Layers.LayerType.Flatten) {
                x2 = model.flatten[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == Layers.LayerType.Dense) {
                x2 = model.dense[layerInfo.layerIndex].forward(x2);
            } else if (layerInfo.layerType == Layers.LayerType.MaxPooling2D) {
                x1 = model.maxPooling2D[layerInfo.layerIndex].forward(x1);
            } else if (layerInfo.layerType == Layers.LayerType.Conv2D) {
                x1 = model.conv2D[layerInfo.layerIndex].forward(x1);
            }

            // the last layer
            if (i == model.layers.length - 1) {
                Tensors.Tensor1D memory xt = Tensor1DMethods.from(x2);
                Float32x32[] memory result = xt.softmax().mat;
                return (x1, result);
            }
        }

        return (x1, x2);
    }

    function classify(
        uint256 fromLayerIndex,
        uint256 toLayerIndex,
        Float32x32[][][] calldata x1,
        Float32x32[] calldata x2
    ) external payable onlyMintedModel {
        if (msg.value < modelRegistry.evalPrice()) revert InsufficientEvalPrice();
        (bool success, ) = modelRegistry.royaltyReceiver().call{value: msg.value}("");
        if (!success) revert TransferFailed();

        if (toLayerIndex >= model.layers.length) {
            toLayerIndex = model.layers.length - 1; // update to the last layer
        }

        (Float32x32[][][] memory r1, Float32x32[] memory r2) = forward(
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

    function setClassesName(
        string[] memory classesName
    ) external onlyOwnerOrOperator {
        model.classesName = classesName;
    }

    function setOnchainModel(
        bytes[] calldata layersConfig
    ) external onlyOwnerOrOperator {
        if (model.layers.length > 0) {
            delete model.input;
            delete model.dense;
            delete model.flatten;
            delete model.rescale;
            delete model.conv2D;
            delete model.maxPooling2D;
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
        } else if (layerType == Layers.LayerType.Conv2D) {
            appendedWeights = model.conv2D[layerInd].appendWeights(weights);
        }
        model.appendedWeights += appendedWeights;
    }

    function makeLayer(
        Layers.SingleLayerConfig memory slc,
        uint256[] memory dim
    ) internal returns (uint256[] memory) {
        uint8 layerType = abi.decode(slc.conf, (uint8));

        // add more layers
        if (layerType == uint8(Layers.LayerType.Input)) {
            (, uint8 inputType) = abi.decode(slc.conf, (uint8, uint8));
            if (inputType != uint8(Layers.InputType.Image)) {
                revert IncorrectInputLayerType();
            }
            (Layers.InputImageLayer memory layer, uint[] memory out_dim) = Layers
                .makeInputImageLayer(slc);
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
        }
        return dim;
    }
}

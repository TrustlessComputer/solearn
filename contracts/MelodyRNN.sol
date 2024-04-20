// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;

// import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./lib/layers/Layers.sol";
// import './lib/Utils.sol';
// import { IModelRegPublic } from "./interfaces/IModelReg.sol";
// import { IMelodyRNN } from "./interfaces/IMelodyRNN.sol";
// // import "hardhat/console.sol";

// error NotTokenOwner();
// error InsufficientEvalPrice();
// error TransferFailed();
// error InvalidOutput();
// error InvalidInput();
// error IncorrectModelId();
// error NotModelRegistry();

// contract MelodyRNN is IMelodyRNN, Ownable {
//     using Layers for Layers.RescaleLayer;
//     using Layers for Layers.FlattenLayer;
//     using Layers for Layers.DenseLayer;
//     using Layers for Layers.MaxPooling2DLayer;
//     using Layers for Layers.Conv2DLayer;
//     using Layers for Layers.EmbeddingLayer;
//     using Layers for Layers.LSTM;
//     using Tensor1DMethods for Tensors.Tensor1D;
//     using Tensor2DMethods for Tensors.Tensor2D;
//     using Tensor3DMethods for Tensors.Tensor3D;
//     using Tensor4DMethods for Tensors.Tensor4D;
//     uint256 constant VOCAB_SIZE = 130;

//     Model public model;
//     IModelRegPublic public modelRegistry;
//     uint256 public modelId;

//     uint256 version;
//     VocabInfo public vocabInfo;

//     modifier onlyOwnerOrOperator() {
//         if (msg.sender != owner() && modelId > 0 && msg.sender != modelRegistry.ownerOf(modelId)) {
//             revert NotTokenOwner();
//         }
//         _;
//     }

//     modifier onlyMintedModel() {
//         if (modelId == 0) {
//             revert IncorrectModelId();
//         }
//         _;
//     }

//     constructor(string memory _modelName, address _modelRegistry) Ownable() {
//         model.modelName = _modelName;
//         modelRegistry = IModelRegPublic(_modelRegistry);        
//         version = 1;
//     }



//     // function initialize(string memory _modelName, address _modelRegistry) public initializer {
//     //     __Ownable_init();
//     //     model.modelName = _modelName;
//     //     modelRegistry = IModelReg(_modelRegistry);        
//     //     version = 1;
//     // }

//     // function afterUpgrade() public {}

//     function getInfo(
//     )
//         public
//         view
//         returns (
//             uint256[3] memory,
//             string memory,
//             Info[] memory
//         )
//     {
//         Model storage m = model;
//         return (
//             model.inputDim,
//             model.modelName,
//             m.layers
//         );
//     }

//     function getDenseLayer(
//         uint256 layerIdx
//     )
//         public
//         view
//         returns (
//             uint256 dim_in,
//             uint256 dim_out,
//             Float32x32[][] memory w,
//             Float32x32[] memory b
//         )
//     {
//         Layers.DenseLayer memory layer = model.d[layerIdx];
//         dim_in = layer.w.n;
//         dim_out = layer.w.m;
//         w = layer.w.mat;
//         b = layer.b.mat;
//     }

//     function getLSTMLayer(
//         uint256 layerIdx
//     )
//         public
//         view
//         returns (
//             uint256,
//             uint256,
//             Float32x32[][] memory,
//             Float32x32[][] memory,
//             Float32x32[] memory
//         )
//     {
//         Layers.LSTM memory layer = model.lstm[layerIdx];
//         Layers.LSTMCell memory cell = layer.cell;
//         uint256 inputUnits = layer.inputUnits;
//         uint256 units = cell.units;
//         return (
//             inputUnits,
//             units,
//             cell.kernel_f.mat,
//             cell.recurrentKernel_f.mat,
//             cell.bias_f.mat
//         );
//     }

//     function forward(
//         Model memory model,
//         uint256 input,
//         Float32x32[][][] memory states,
//         bool isGenerating
//     ) internal returns (Float32x32[] memory, Float32x32[][][] memory) {
//         Float32x32[] memory x2;
//         Float32x32[][] memory x2Ext;
//         for (uint256 i = 0; i < model.layers.length; i++) {
//             Info memory layerInfo = model.layers[i];

//             // add more layers
//             if (layerInfo.layerType == LayerType.Embedding) {
//                 x2 = model.embedding[layerInfo.layerIndex].forward(input);
//                 // console.log("embedding ", layerInfo.layerIndex);
//                 // for(uint j = 0; j < x2.length; ++j) {
//                 //     console.logInt(x2[j].intoInt256());
//                 // }
//             } else if (layerInfo.layerType == LayerType.Dense) {
//                 if (i < model.layers.length - 1 || isGenerating) {
//                     x2 = model.d[layerInfo.layerIndex].forward(x2);
//                     // console.log("dense ", layerInfo.layerIndex);
//                     // for(uint j = 0; j < x2.length; ++j) {
//                     //     console.logInt(x2[j].intoInt256());
//                     // }
//                 }                
//             } else if (layerInfo.layerType == LayerType.LSTM) {
//                 if (x2.length == 0) {
//                     x2 = new Float32x32[](1);
//                     x2[0] = Float32x32.wrap(int64(int((input << 32) / VOCAB_SIZE)));
//                 }

//                 Layers.LSTM memory lstm = model.lstm[layerInfo.layerIndex];
//                 (x2Ext, states[layerInfo.layerIndex]) = lstm.forward(x2, states[layerInfo.layerIndex]);
//                 x2 = x2Ext[0];

//                 // console.log("states[0] of lstm", layerInfo.layerIndex);
//                 // for(uint j = 0; j < states[layerInfo.layerIndex][0].length; ++j) {
//                 //     console.logInt(states[layerInfo.layerIndex][0][j].intoInt256());
//                 // }
//                 // console.log("states[1] of lstm", layerInfo.layerIndex);
//                 // for(uint j = 0; j < states[layerInfo.layerIndex][1].length; ++j) {
//                 //     console.logInt(states[layerInfo.layerIndex][1][j].intoInt256());
//                 // }
//             }
//         }
//         return (x2, states);
//     }

//     function decodeTokens(Float32x32[] memory tokens) internal view returns (Float32x32[] memory) {
//         VocabInfo storage info = vocabInfo;
//         for(uint i = 0; i < tokens.length; ++i) {
//             uint64 id = uint64(toInt(tokens[i]));
//             tokens[i] = fromInt(int(info.vocabs[id]));
//         }
//         return tokens;
//     }

//     function getVocabs() public view returns (uint256[] memory) {
//         return vocabInfo.vocabs;
//     }

//     function getToken(
//         Float32x32[] memory x2,
//         Float32x32 temperature,
//         uint256 seed 
//     ) internal view returns (uint256) {
//         Float32x32[] memory tmp = Utils.clone(x2);
//         for(uint i = 0; i < tmp.length; ++i) {
//             tmp[i] = tmp[i] / temperature;
//         }

//         Tensors.Tensor1D memory xt = Tensor1DMethods.from(tmp);
//         Float32x32[] memory probs = xt.softmax().mat;
//         uint256 outputToken = Utils.getWeightedRandom(probs, seed);

//         return outputToken;
//     }

//     function generateMelody(
//         uint256 _modelId,
//         uint256 noteCount,
//         Float32x32[] calldata x
//     ) external onlyMintedModel {
//         if (_modelId != modelId) revert IncorrectModelId();
        
//         Model memory model = model;
//         uint256 seed = uint256(keccak256(abi.encodePacked(x)));

//         Float32x32 temperature = Float32x32.wrap(1 << 32); // 1.0
//         Float32x32[] memory r2;
//         Float32x32[][][] memory states = new Float32x32[][][](model.lstm.length);
//         for (uint256 i=0; i<x.length-1; i++) {
//             (r2, states) = forward(model, uint(int(toInt(x[i]))), states, false);
//         }

//         Float32x32[] memory result = new Float32x32[](noteCount);
//         uint256 inputToken = uint(int(toInt(x[x.length - 1])));
//         for (uint256 i=0; i<noteCount; i++) {
//             (r2, states) = forward(model, inputToken, states, true);
//             uint256 nxtToken = getToken(r2, temperature, seed);
//             if (vocabInfo.hasVocab) {
//                 nxtToken = vocabInfo.vocabs[nxtToken];
//             }
//             result[i] = fromInt(int(nxtToken));
//             seed = uint256(keccak256(abi.encodePacked(seed)));
//             inputToken = nxtToken;
//         }

//         emit NewMelody(modelId, result);
//     }


//     function setModel(
//         bytes[] calldata layers_config
//     ) external onlyOwnerOrOperator {

//         if (model.numLayers > 0) {
//             model.numLayers = 0;
//             delete model.d;
//             delete model.f;
//             delete model.r;
//             delete model.lstm;
//             delete model.embedding;
//             delete model.layers;
//         }

//         loadModel(layers_config);
//     }

//     function appendWeights(
//         Float32x32[] memory weights,
//         uint256 layerInd,
//         LayerType layerType
//     ) external onlyOwnerOrOperator {
//         uint appendedWeights;
//         if (layerType == LayerType.Dense) {
//             appendedWeights = model.d[layerInd].appendWeights(weights);
//         } else if (layerType == LayerType.LSTM) {
//             appendedWeights = model.lstm[layerInd].appendWeightsPartial(weights);
//         } else if (layerType == LayerType.Embedding) {
//             appendedWeights = model.embedding[layerInd].appendWeights(weights);
//         }
        
//         model.appendedWeights += appendedWeights;
//         if (model.appendedWeights == model.requiredWeights && modelId > 0) {
//             emit Deployed(modelRegistry.ownerOf(modelId), modelId);
//         }
//     }
    
//     function setVocabs(
//         uint256[] memory vocabs
//     ) external onlyOwnerOrOperator {
//         VocabInfo storage info = vocabInfo;
//         info.vocabs = vocabs;
//         info.hasVocab = true;
//     }

//     function makeLayer(
//         Layers.SingleLayerConfig memory slc,
//         uint256[3] memory dim1,
//         uint256 dim2
//     ) internal returns (uint256[3] memory, uint256) {
//         uint8 layerType = abi.decode(slc.conf, (uint8));

//         // add more layers
//         if (layerType == uint8(LayerType.Dense)) {
//             (Layers.DenseLayer memory layer, uint out_dim2, uint weights) = Layers
//                 .makeDenseLayer(slc, dim2);
//             model.d.push(layer);
//             model.requiredWeights += weights;
//             dim2 = out_dim2;

//             uint256 index = model.d.length - 1;
//             model.layers.push(Info(LayerType.Dense, index));
//         } else if (layerType == uint8(LayerType.Embedding)) {
//             (Layers.EmbeddingLayer memory layer, uint out_dim2, uint weights) = Layers
//                 .makeEmbeddingLayer(slc);
//             model.embedding.push(layer);
//             model.requiredWeights += weights;
//             dim2 = out_dim2;

//             uint256 index = model.embedding.length - 1;
//             model.layers.push(Info(LayerType.Embedding, index));
//         } else if (layerType == uint8(LayerType.Flatten)) {
//             (Layers.FlattenLayer memory layer, uint out_dim2) = Layers
//                 .makeFlattenLayer(slc, dim1);
//             model.f.push(layer);
//             dim2 = out_dim2;

//             uint256 index = model.f.length - 1;
//             model.layers.push(Info(LayerType.Flatten, index));
//         } else if (layerType == uint8(LayerType.Rescale)) {
//             Layers.RescaleLayer memory layer = Layers.makeRescaleLayer(slc);
//             model.r.push(layer);

//             uint256 index = model.r.length - 1;
//             model.layers.push(Info(LayerType.Rescale, index));
//         } else if (layerType == uint8(LayerType.Input)) {
//             (, uint8 inputType) = abi.decode(slc.conf, (uint8, uint8));
//             if (inputType == 0) {
//                 dim2 = 1;
//             } else if (inputType == 1) {
//                 (, , uint256[3] memory ipd) = abi.decode(
//                     slc.conf,
//                     (uint8, uint8, uint256[3])
//                 );
//                 model.inputDim = ipd;
//                 dim1 = ipd;
//             }

//             // NOTE: there is only one layer type input
//             model.layers.push(Info(LayerType.Input, 0));
//         } else if (layerType == uint8(LayerType.LSTM)) {
//             (Layers.LSTM memory layer, uint256 out_dim, uint256 rw) = Layers
//                 .makeLSTMLayer(slc, dim2);
//             model.lstm.push(layer);
//             model.requiredWeights += rw;
//             dim1 = dim1;
//             dim2 = out_dim;

//             uint256 index = model.lstm.length - 1;
//             model.layers.push(Info(LayerType.LSTM, index));
//         }
//         return (dim1, dim2);
//     }

//     function loadModel(
//         bytes[] calldata layersConfig
//     ) internal {
//         model.numLayers = layersConfig.length;
//         model.requiredWeights = 0;
//         model.appendedWeights = 0;
//         uint256[3] memory dim1;
//         uint256 dim2;
//         for (uint256 i = 0; i < layersConfig.length; i++) {
//             (dim1, dim2) = makeLayer(
//                 Layers.SingleLayerConfig(layersConfig[i], i),
//                 dim1,
//                 dim2
//             );
//         }
//     }

//     function setModelId(uint256 _modelId) external {
//         if (msg.sender != address(modelRegistry)) {
//             revert NotModelRegistry();
//         }
//         if (modelId > 0 || modelRegistry.modelAddr(_modelId) != address(this)) {
//             revert IncorrectModelId();
//         }

//         modelId = _modelId;
//         if (model.appendedWeights == model.requiredWeights && modelId > 0) {
//             emit Deployed(modelRegistry.ownerOf(modelId), modelId);
//         }
//     }
// }

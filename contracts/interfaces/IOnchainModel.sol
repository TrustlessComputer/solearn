// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IModel } from "./IModel.sol";

interface IOnchainModel is IModel {
    event Deployed(
        address indexed owner,
        uint256 indexed tokenId
    );
    
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
    
    struct Info {
        LayerType layerType;
        uint256 layerIndex;
    }    
}

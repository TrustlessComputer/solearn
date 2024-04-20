// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IModel } from "./IModel.sol";
import { Layers } from "./../lib/layers/Layers.sol";

interface IOnchainModel is IModel {
    event Deployed(
        address indexed owner,
        uint256 indexed tokenId
    );
    
    struct Info {
        Layers.LayerType layerType;
        uint256 layerIndex;
    }    
}

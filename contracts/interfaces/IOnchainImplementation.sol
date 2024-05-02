// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../lib/layers/Layers.sol";

interface IOnchainImplementation {
    error Unauthorized();

    struct Info {
        Layers.LayerType layerType;
        uint256 layerIndex;
    }

    function isReady() external returns (bool);
    function setModelInterface(address _interface) external;
    function infer(bytes calldata _data) external returns (bytes memory result);
}

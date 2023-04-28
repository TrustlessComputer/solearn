// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SD59x18 } from "@prb/math/src/SD59x18.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPerceptrons is IERC721Enumerable {
    function evaluate(uint256 modelId, SD59x18[] memory pixels) external view returns (string memory);
    function setWeights(uint256 modelId, bytes[] memory layers_config, SD59x18[][][] calldata weights, SD59x18[][] calldata biases, int appendLayer) external;
    function getInfo(uint256 modelId) external view returns (uint256, uint256, uint256, uint256);
    function safeMint(address to, uint256 modelId, string memory uri, string memory modelName, string[] memory classesName) external payable;
    function forward(uint256 modelId, SD59x18[] memory pixels) external view returns (SD59x18[] memory);
}
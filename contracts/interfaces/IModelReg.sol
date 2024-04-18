// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

interface IModelReg {
  function modelAddr(uint256 tokenId) external view returns (address);
  function evalPrice() external view returns (uint256);
  function royaltyReceiver() external view returns (address);
}

interface IModelRegPublic is IModelReg, IERC721Upgradeable {}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IModels} from "../Models.sol";

interface IHybridModel is IModels {
    event WorkerHubUpdate(address newAddress);

    event IdentifierUpdate(uint256 newValue);
    event InferenceCostUpdate(uint256 newValue);
    event NameUpdate(string newValue);
    event UrlUpdate(string newValue);

    error InsufficientFunds();
    error ModelIdAlreadySet();

    function version() external pure returns (string memory version);

    function identifier() external view returns (uint256 identifier);
    function inferenceCost() external view returns (uint256 inferenceCost);
    function name() external view returns (string memory name);
    function url() external view returns (string memory url);

    function infer(bytes calldata _data) external payable returns (uint256 referenceId);
}

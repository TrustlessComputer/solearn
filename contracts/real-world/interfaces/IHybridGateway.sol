// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IGateway} from "./IGateway.sol";

interface IHybridGateway is IGateway {
    event WorkerHubUpdate(address newAddress);

    event IdentifierUpdate(uint256 newValue);
    event NameUpdate(string newValue);
    event MetadataUpdate(string newValue);

    error GatewayIdAlreadySet();

    function version() external pure returns (string memory version);

    function identifier() external view returns (uint256 identifier);
    function metadata() external view returns (string memory metadata);
    function name() external view returns (string memory name);

    function infer(
        bytes calldata _data
    ) external payable returns (uint256 referenceId);

    function infer(
        bytes calldata _data,
        bool flag
    ) external payable returns (uint256 referenceId);

    function infer(
        bytes calldata _data,
        address creator
    ) external payable returns (uint256 referenceId);

    function infer(
        bytes calldata _data,
        address creator,
        bool flag
    ) external payable returns (uint256 referenceId);
}

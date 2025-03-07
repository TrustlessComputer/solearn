// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IETHRegistrarController} from "../interfaces/IETHRegistrarController.sol";
import {IResolver} from "../interfaces/IResolver.sol";

abstract contract ETHRegistrar is IETHRegistrarController {
    IETHRegistrarController public registrar;
    IResolver public resolver;

    bytes32 private constant NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

    function __ETHRegistrar_init(IETHRegistrarController _registrar, IResolver _resolver)
        external
    {
        registrar = _registrar;
        resolver = _resolver;
    }

    function commit(bytes32 commitment) external {
        registrar.commit(commitment);
    }

    function register(string memory name, uint256 duration, bytes32 secret, bytes[] memory data) external payable {
        registrar.register{value: msg.value}(name, address(this), duration, secret, address(resolver), data, true, 0);
    }

    function renew(string memory name, uint256 duration) external payable {
        registrar.renew{value: msg.value}(name, duration);
    }

    function getAddressByENS(string memory name) public view returns (address) {
        bytes32 node = keccak256(abi.encodePacked(NODE, keccak256(bytes(name))));
        return resolver.addr(node);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

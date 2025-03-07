// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBASERegistrarController, RegisterRequest} from "../interfaces/IBASERegistrarController.sol";
import {IResolver} from "../interfaces/IResolver.sol";

abstract contract BASERegistrar is IBASERegistrarController {
    IBASERegistrarController public registrar;
    IResolver public resolver;

    bytes32 private constant NODE =
        0xff1e3c0eb00ec714e34b6114125fbde1dea2f24a72fbf672e7b7fd5690328e10;

    function __BASERegistrar_init(IBASERegistrarController _registrar, IResolver _resolver)
        external
    {
        registrar = _registrar;
        resolver = _resolver;
    }

    function register(string memory name, uint256 duration) external payable {
        bytes[] memory data = new bytes[](2);
        bytes32 node = keccak256(abi.encodePacked(NODE, keccak256(bytes(name))));

        // set addr
        bytes memory data1 = abi.encodeWithSelector(IResolver.setAddr.selector, node, 60, abi.encodePacked(address(this)));
        data[0] = data1;

        // set name to name
        bytes memory data2 = abi.encodeWithSelector(IResolver.setName.selector, node, name);
        data[1] = data2;

        registrar.register{value: msg.value}(
            RegisterRequest({
                name: name,
                owner: address(this),
                duration: duration,
                data: data,
                resolver: address(resolver),
                reverseRecord: true
            })
        );
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

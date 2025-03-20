// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBASERegistrarController, RegisterRequest} from "../interfaces/IBASERegistrarController.sol";
import {IResolver} from "../interfaces/IResolver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BASERegistrar is Initializable {
    IBASERegistrarController public registrar;
    IResolver public resolver;

    function __BASERegistrar_init(string calldata agentName, bytes calldata nameService)
        internal onlyInitializing
    {
        (address _registrar, address _resolver, uint _duration) = abi.decode(nameService, (address, address, uint));        

        registrar = IBASERegistrarController(_registrar);
        resolver = IResolver(_resolver);

        register(agentName, _duration, registrar.rootNode());
    }

    function register(string memory name, uint256 duration, bytes32 baseNode) internal {
        bytes[] memory data = new bytes[](2);
        bytes32 node = keccak256(abi.encodePacked(baseNode, keccak256(bytes(name))));

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

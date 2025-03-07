// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IARBRegistrarController, ReferralInfo} from "../interfaces/IARBRegistrarController.sol";
import {IResolver} from "../interfaces/IResolver.sol";

abstract contract ARBRegistrar is IARBRegistrarController {
    IARBRegistrarController public registrar;
    IResolver public resolver;

    bytes32 private constant NODE =
        0xd924c6d6935f3bf84be3da0b40fabe48800690c760c2db576028a389f1b54f89;

    function __BASERegistrar_init(IARBRegistrarController _registrar, IResolver _resolver)
        external
    {
        registrar = _registrar;
        resolver = _resolver;
    }

    function bulkRegister(string[] calldata names, uint duration) external payable {
        registrar.bulkRegister(names, address(this), duration, address(resolver), false, true, ReferralInfo({
            referrerAddress: address(0),
            referrerNodehash: bytes32(0),
            referralAmount: 0,
            signedAt: 0,
            signature: new bytes(0)
        }));
    }

    function renew(string memory name, uint256 duration) external payable {
        registrar.renew(name, duration);
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

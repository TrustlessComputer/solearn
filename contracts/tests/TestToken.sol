// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract TestToken is ERC20PermitUpgradeable {
    function initialize(
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ERC20_init(_name, _symbol);
    }

    function mintFor(address[] calldata _owners, uint256 _amount) external {
        uint256 n = _owners.length;
        for (uint256 i = 0; i < n; ++i) _mint(_owners[i], _amount);
    }
    
    function mintFor(address _owner, uint256 _amount) external {
        _mint(_owner, _amount);
    }
}
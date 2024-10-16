// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC20Mint {
    function mint(address to, uint amount) external;
}

contract MintingContract1 {
    ERC20Mint immutable public daoToken;

    constructor(address _daoToken) {
        daoToken = ERC20Mint(_daoToken);
    }

    // func exeMint(bytes data) {} 
    //Parse data -> address[] receivers, uint256[] amounts. 
    function exeMint(address[] memory _receivers, uint[] memory _amounts) external {
        require(_receivers.length == _amounts.length && _receivers.length > 0, "m"); // must equal

        for (uint i; i < _receivers.length; i++) {
            daoToken.mint(_receivers[i], _amounts[i]);
        }
    }
}
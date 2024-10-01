// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IDAOToken} from "./tokens/IDAOToken.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

contract Treasury is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public daoToken;
    uint256[100] private __gap;

    event Withdraw(uint256 _amount, address _to);
    event Receive(uint256 _amount, address _from);

    function initialize(address _daoToken) external initializer {
        require(
            _daoToken != address(0),
            "Treasury: daoToken is the zero address"
        );
        __Ownable_init();
        __ReentrancyGuard_init();

        daoToken = _daoToken;
    }

    receive() external payable {
        emit Receive(msg.value, msg.sender);
    }

    function withdraw(
        uint256 _amount,
        address _to
    ) external onlyOwner nonReentrant {
        require(
            _amount > 0 && _amount <= address(this).balance,
            "Invalid amount"
        );
        require(_to != address(0), "Invalid address");

        TransferHelper.safeTransferNative(_to, _amount);
        emit Withdraw(_amount, _to);
    }
}

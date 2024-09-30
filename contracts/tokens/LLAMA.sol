// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IDAOToken} from "./IDAOToken.sol";
import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

contract LLAMA is IDAOToken, ERC20Upgradeable, OwnableUpgradeable {
    IWorkerHub public workerHub;
    uint256 public constant MAX_SUPPLY = 21 * 1e6 * 1e18; // 21M

    modifier onlyWorkerHub() {
        require(
            msg.sender == address(workerHub),
            "LLAMA: caller is not the workerHub"
        );
        _;
    }

    function initialize(address _workerHub) public initializer {
        require(
            _workerHub != address(0),
            "LLAMA: workerHub is the zero address"
        );

        __ERC20_init("LLAMA", "LLAMA");
        __Ownable_init();
        workerHub = IWorkerHub(_workerHub);
    }

    function mint(address to, uint256 amount) public onlyWorkerHub {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "LLAMA: max supply exceeded"
        );
        _mint(to, amount);
    }

    function mintBatch(
        address[] memory to,
        uint256[] memory amount
    ) public onlyWorkerHub {
        require(to.length == amount.length, "LLAMA: length mismatch");

        for (uint256 i = 0; i < to.length; i++) {
            require(
                totalSupply() + amount[i] <= MAX_SUPPLY,
                "LLAMA: max supply exceeded"
            );
            _mint(to[i], amount[i]);
        }
    }

    function validateSupplyIncrease(
        uint256 _amount
    ) external view returns (bool) {
        return totalSupply() + _amount <= MAX_SUPPLY;
    }
}

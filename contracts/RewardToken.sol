// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// erc20 token 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "hardhat/console.sol";

contract RewardToken is ERC20 {
	constructor() ERC20("AI Reward Token", "AIR") {
		_mint(msg.sender, 1000000000000000000000000000);
	}
}

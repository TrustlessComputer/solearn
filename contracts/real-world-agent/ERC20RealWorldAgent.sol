// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {RealWorldAgent} from "./RealWorldAgent.sol";

contract ERC20RealWorldAgent is ERC20, ERC20Permit, ERC20Votes, RealWorldAgent {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 amount_,
        address recipient_,
        uint256 minFeeToUse_,
        uint32 timeout_,
        IERC20 tokenFee_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        RealWorldAgent(minFeeToUse_, timeout_, tokenFee_)
    {
        _mint(recipient_, amount_);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        return ERC20Votes._mint(account, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._burn(account, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }
}

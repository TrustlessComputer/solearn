// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAI20} from "./IAI20.sol";

contract AI20 is ERC20, IAI20 {

    string private _prompt;
    uint256 private _fee;
    uint256 private _modelId;

    constructor(string memory name_, string memory symbol_, string memory prompt_, uint256 fee_, uint256 modelId_) ERC20(name_, symbol_) {
        _setPrompt(prompt_);
        _setFee(fee_);
        _setModelId(modelId_);
    }

    /**
     * @dev Returns the promt of this AI contract.
     */
    function prompt() public view virtual override returns (string memory) {
        return _prompt;
    }

    function _setPrompt(string memory newPrompt) internal virtual {
        require(bytes(newPrompt).length != 0, "AI20: new prompt is null");

        emit PromptSet(_prompt, newPrompt);

        _prompt = newPrompt;
    }

    function fee() public view virtual override returns (uint256) {
        return _fee;
    }

    function _setFee(uint256 newFee) internal virtual {
        emit FeeSet(_fee, newFee);

        _fee = newFee;
    }

    function modelId() public view virtual override returns (uint256) {
        return _modelId;
    }

    function _setModelId(uint256 newModelId) internal virtual {
        _modelId = newModelId;
    }

    // todo
    function infer() public view virtual override returns (uint256) {

    }

}
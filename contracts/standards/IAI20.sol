// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IAI20 {
    /**
     * @dev Emitted when the prompt is set.
     */
    event PromptSet(string oldPrompt, string newPrompt);

    /**
     * @dev Emitted when the fee is set.
     */
    event FeeSet(uint oldFee, uint newFee);

    /**
     * @dev Emitted when the modelId is set.
     */
    event ModelIdSet(uint oldModelId, uint newModelId);

    /**
     * @dev Returns the promt of this AI contract.
     */
    function prompt() external view returns (string memory);

    /**
     * @dev Returns the fee of this AI contract.
     */
    function fee() external view returns (uint256);

    /**
     * @dev Returns the modelId of this AI contract.
     */
    function modelId() external view returns (uint256);

    /**
     * @dev Execute infer request.
     */
    function infer() external  returns (uint256);
}

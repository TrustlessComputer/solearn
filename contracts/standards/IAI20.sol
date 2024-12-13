// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IAI20 {
    struct TokenMetaData {
        uint256 fee;
        mapping(string => bytes[]) sysPrompts;
    }

    event AgentURIUpdate(string uri);
    event AgentDataUpdate(
        uint256 promptIndex,
        bytes oldSysPrompt,
        bytes newSysPrompt
    );
    event AgentDataAddNew(bytes[] sysPrompt);
    event AgentFeeUpdate(uint fee);
    event InferencePerformed(
        address indexed caller,
        bytes data,
        uint fee,
        string externalData,
        uint256 inferenceId
    );
    event TopUpPoolBalance(address caller, uint256 amount);

    event AgentMissionAddNew(bytes[] missions);
    event AgentMissionUpdate(
        uint256 missionIndex,
        bytes oldSysMission,
        bytes newSysMission
    );

    error InsufficientFunds();
    error InvalidAgentFee();
    error InvalidAgentData();
    error Unauthorized();
    error InvalidData();
        error InvalidAgentPromptIndex();

    function getMission() external view returns (bytes[] memory);
    function topUpPoolBalance(uint256 amount) external;

    /**
     * @dev Execute infer request.
     */
    function infer(
        bytes calldata fwdCalldata,
        string calldata externalData,
        string calldata promptKey,
        uint256 modelId,
        uint256 feeAmount
    ) external payable;

    function infer(
        bytes calldata _calldata,
        string calldata _externalData,
        string calldata _promptKey,
        uint256 _modelId,
        bool _flag,
        uint256 _feeAmount
    ) external payable;
}
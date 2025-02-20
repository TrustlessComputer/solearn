// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ICommonAgent {
    struct RequestInfo {
        address agentAddress;
        uint64 actionId;
    }

    error InvalidData();
    error ZeroAddress();
    error DuplicateUuid();

    event PromptSchedulerUpdate(address promptScheduler);
    event ModelUpdate(address hybridModel);
    event SystemPromptUpdate(string newSystemPrompt);
    event PromptPerformed(
        bytes32 indexed uuid,
        uint256 indexed inferId,
        address indexed caller,
        bytes executionData
    );

    function updateSystemPrompt(string memory _systemPrompt) external;
    function getSystemPrompt() external view returns (string memory);

    function getResultById(bytes32 uuid) external view returns (bytes memory);
    function getResultById(
        uint256 promptId
    ) external view returns (bytes memory);

    function prompt(bytes memory request) external payable returns (uint256);
    function prompt(
        bytes32 uuid,
        bytes memory request
    ) external payable returns (uint256 inferId);
}

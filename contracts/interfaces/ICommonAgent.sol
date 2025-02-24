// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ICommonAgent {
    struct RequestInfo {
        address agentAddress;
        uint64 actionId;
    }

    event PromptSchedulerUpdate(address promptScheduler);
    event ModelUpdate(address hybridModel);
    event SystemPromptUpdate(string newSystemPrompt);

    error InvalidData();
    error ZeroAddress();
    error DuplicateUuid();

    function updateSystemPrompt(string calldata _systemPrompt) external;
    function getSystemPrompt() external view returns (string memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {IAgent} from "./IAgent.sol";

interface IAgentFactory {
    event AgentCreated(bytes32 indexed agentId, address indexed agent);
    event ImplementationSet(address indexed implementation);

    function createAgent(
        bytes32 agentId,
        string calldata agentName,
        string calldata agentVersion,
        string calldata codeLanguage,
        IAgent.CodePointer[] calldata pointers,
        address[] calldata depsAgents,
        address agentOwner
    ) external returns (address agent);

    function getImplementation() external view returns (address);
}
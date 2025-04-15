// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import {IAgentFactory, IAgent} from "./IAgentFactory.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AgentUpgradeable} from "./AgentUpgradeable.sol";
import {AgentProxy} from "./AgentProxy.sol";

contract AgentFactory is IAgentFactory, OwnableUpgradeable {

    uint256 constant DURATION = 10 * 365 days; // 10 years

    address _implementation;
    // agentId => agent address
    mapping (bytes32 => address) public agents;
    // name service param
    address _registrar;
    address _resolver;

    function initialize(
        address owner, 
        address implementation,
        address registrar,
        address resolver
    ) public initializer {
        _transferOwnership(owner);

        _registrar = registrar;
        _resolver = resolver;
        _implementation = implementation;
    }

   function createAgent(
        bytes32 agentId,
        string calldata agentName,
        string calldata agentVersion,
        string calldata codeLanguage,
        IAgent.CodePointer[] memory pointers,
        address[] calldata depsAgents,
        address agentOwner
    ) external returns (address agent) {
        require(agents[agentId] == address(0), "Agent already exists");

        agent = address(new AgentProxy());
        AgentUpgradeable(agent).initialize(
            agentName, 
            agentVersion, 
            codeLanguage, 
            pointers, 
            depsAgents, 
            agentOwner, 
            abi.encode(_registrar, _resolver, DURATION)
        );
        AgentUpgradeable(agent).transferOwnership(_msgSender());

        agents[agentId] = agent;
        emit AgentCreated(agentId, agent);
    }

    function setImplementation(address implementation) external onlyOwner {
        _implementation = implementation;

        emit ImplementationSet(implementation);
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }

}
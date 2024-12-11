// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IAI721 {
    struct TokenMetaData {
        uint256 fee;
        bytes[] sysPrompts;
    }

    event MintPriceUpdate(uint256 newValue);
    event RoyaltyPortionUpdate(uint16 newValue);
    event RoyaltyReceiverUpdate(address newAddress);
    event ManagerAuthorization(address indexed account);
    event ManagerDeauthorization(address indexed account);
    event NewToken(
        uint256 indexed tokenId,
        string uri,
        bytes sysPrompt,
        uint fee,
        address indexed minter
    );
    event AgentURIUpdate(uint256 indexed agentId, string uri);
    event AgentDataUpdate(
        uint256 indexed agentId,
        uint256 promptIndex,
        bytes oldSysPrompt,
        bytes newSysPrompt
    );
    event AgentDataAddNew(uint256 indexed agentId, bytes[] sysPrompt);
    event AgentFeeUpdate(uint256 indexed agentId, uint fee);
    event InferencePerformed(
        uint256 indexed tokenId,
        address indexed caller,
        bytes data,
        uint fee,
        string externalData,
        uint256 inferenceId
    );
    event FeesClaimed(address indexed claimer, uint amount);
    event TopUpPoolBalance(uint256 agentId, address caller, uint256 amount);

    event AgentMissionAddNew(uint256 indexed agentId, bytes[] missions);
    event AgentMissionUpdate(
        uint256 indexed agentId,
        uint256 missionIndex,
        bytes oldSysMission,
        bytes newSysMission
    );

    error Authorized();
    error FailedTransfer();
    error InsufficientFunds();
    error InvalidMintingFee();
    error InvalidAgentId();
    error InvalidAgentFee();
    error InvalidAgentData();
    error InvalidAgentURI();
    error InvalidAgentPromptIndex();
    error SignatureUsed();
    error Unauthorized();
    error InvalidData();

    function nextTokenId() external view returns (uint256 nextTokenId);
    function royaltyReceiver() external view returns (address royaltyReceiver);
    function royaltyPortion() external view returns (uint16 royaltyPortion);
    function getAgentIdByOwner(address _owner) external view returns (uint256[] memory);
    function createMission(uint256 _agentId, bytes calldata _missionData) external;
    function getMissionIdsByAgentId(uint256 _agentId) external view returns (bytes[] memory);
    function updateAgentURI(uint256 agentId, string calldata uri) external;
    function updateAgentData(uint256 agentId, bytes calldata sysPrompt, uint256 promptIdx) external;
    function updateAgentDataWithSignature(
        uint256 agentId,
        bytes calldata sysPrompt,
        uint256 promptIdx,
        uint256 randomNonce,
        bytes calldata signature
    ) external;

    function updateAgentUriWithSignature(
        uint256 agentId,
        string calldata uri,
        uint256 randomNonce,
        bytes calldata signature
    ) external;

    function addNewAgentData(
        uint256 agentId,
        bytes calldata sysPrompt
    ) external;

    function updateAgentFee(
        uint256 agentId,
        uint fee
    ) external;

    function topUpPoolBalance(uint256 _agentId) external payable;

    /**
     * @dev Execute infer request.
     */
    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData
    ) external payable;

    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData,
        bool _flag
    ) external payable;
}

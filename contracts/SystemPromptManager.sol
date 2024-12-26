// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {EIP712Upgradeable, ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// import {IStakingHub} from "./interfaces/IStakingHub.sol";
import {IWorkerHub} from "./interfaces/IWorkerHub.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {SystemPromptManagerStorage} from "./storages/SystemPromptManagerStorage.sol";
import {ISquad} from "./interfaces/ISquad.sol";
import {Base64Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import {ICryptoAIData} from "./interfaces/ICryptoAIData.sol";
import {IAI721Upgradeable, IStakingHub, IInferable} from "./standardUpgradeable/interfaces/IAI721Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "hardhat/console.sol";

contract SystemPromptManager is
    SystemPromptManagerStorage,
    EIP712Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721PausableUpgradeable,
    ERC721URIStorageUpgradeable,
    IAI721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    string private constant VERSION = "v0.0.1";
    uint256 private constant PORTION_DENOMINATOR = 10000;

    uint64 private constant NFT_UNLOCK_THRESHOLD = 100;
    uint64 private constant NFT_COLLECTION_SIZE = 10000;
    uint256 private constant MAX_RARITY = 10000;
    uint256 private constant a1 = 15;
    uint256 private constant a2 = 1;
    uint256 private constant a3 = 2000;
    uint256 private constant a4 = 180;
    uint256 private constant b1 = 9000000;
    uint256 private constant b2 = 1;
    uint256 private constant b3 = 4000000;
    uint256 private constant b4 = 1;

    receive() external payable {}

    modifier onlyManager() {
        if (msg.sender != owner() && !isManager[msg.sender])
            revert Unauthorized();
        _;
    }

    modifier onlyAgentOwner(uint256 _agentId) {
        _checkAgentOwner(msg.sender, _agentId);
        _;
    }

    function _checkAgentOwner(address _user, uint256 _agentId) internal view {
        address owner = agentInfo[_agentId].owner;
        if (owner == address(0)) {
            owner = _ownerOf(agentInfo[_agentId].tokenId);
        }

        if (_user != owner) revert Unauthorized();
    }

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _mintPrice,
        address _argRoyaltyReceiver,
        uint16 _argRoyaltyPortion,
        uint256 _argNextTokenId,
        address _workerHub,
        address _stakingHub,
        address _feeTokenAddr,
        address _cryptoAiDataAddr
    ) external initializer {
        require(
            _stakingHub != address(0) && _workerHub != address(0),
            "Zero address"
        );

        __ERC721_init(_name, _symbol);
        __ERC721Pausable_init();
        __Ownable_init();

        mintPrice = _mintPrice;
        _royaltyReceiver = _argRoyaltyReceiver;
        _royaltyPortion = _argRoyaltyPortion;
        _nextTokenId = _argNextTokenId;
        stakingHub = _stakingHub;
        workerHub = _workerHub;
        cryptoAiDataAddr = _cryptoAiDataAddr;
        feeTokenAddr = _feeTokenAddr;

        isManager[owner()] = true;
        nextAgentId = 1;
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function authorizeManager(address _account) external onlyOwner {
        if (isManager[_account]) revert Authorized();
        isManager[_account] = true;
        emit ManagerAuthorization(_account);
    }

    function deauthorizeManager(address _account) external onlyOwner {
        if (!isManager[_account]) revert Unauthorized();
        isManager[_account] = false;
        emit ManagerDeauthorization(_account);
    }

    function updateMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdate(_mintPrice);
    }

    function updateRoyaltyReceiver(
        address _argRoyaltyReceiver
    ) external onlyOwner {
        _royaltyReceiver = _argRoyaltyReceiver;
        emit RoyaltyReceiverUpdate(_royaltyReceiver);
    }

    function updateRoyaltyPortion(uint16 _argRoyaltyPortion) external onlyOwner {
        _royaltyPortion = _argRoyaltyPortion;
        emit RoyaltyPortionUpdate(_royaltyPortion);
    }

    function transferAgentOwnership(
        address _newOwner,
        uint256 _agentId
    ) external {
        address owner = agentInfo[_agentId].owner;
        // exclude minted agents
        if (owner == address(0)) {
            revert InvalidStatus();
        }
        if (owner != msg.sender) {
            revert Unauthorized();
        }

        if (_newOwner == address(0)) revert InvalidData();
        agentInfo[_agentId].owner = _newOwner;

        emit AgentOwnerUpdate(_agentId, _newOwner);
    }

    function createAgent(
        address _agentOwner,
        string calldata _promptKey,
        bytes calldata _data,
        uint128 _fee,
        uint32 _modelId
    ) external returns (uint256) {
        if (_data.length == 0) revert InvalidAgentData();
        uint256 agentId = nextAgentId++;
        AgentRating storage a = agentRating[agentId];
        if (agentInfo[agentId].status != AgentStatus.Empty) revert InvalidStatus();

        datas[agentId].fee = _fee;
        datas[agentId].modelId = uint32(_modelId);
        datas[agentId].sysPrompts[_promptKey].push(_data);

        agentInfo[agentId].owner = _agentOwner;
        agentInfo[agentId].status = AgentStatus.Pending;

        emit NewAgent(agentId, _data, _fee, _agentOwner);
    }

    function mint_(
        address _to,
        // string calldata _uri,
        // bytes calldata _data,
        // uint _fee,
        uint256 tokenId,
        uint256 agentId
    ) internal returns (uint256) {
        AgentRating storage a = agentRating[agentId];
        if (agentInfo[agentId].status != AgentStatus.Pending) revert InvalidStatus();
        if (a.totalPoints < NFT_UNLOCK_THRESHOLD) revert ThresholdNotReached();
        if (tokenId > NFT_COLLECTION_SIZE) revert CollectionSizeReached();

        _safeMint(_to, tokenId);
        // _setTokenURI(agentId, _uri);

        agentInfo[agentId].tokenId = tokenId;
        agentInfo[agentId].owner = address(0);
        agentInfo[agentId].status = AgentStatus.Minted;

        agentRating[agentId].mintTime = uint64(block.timestamp);
        tokenIdToAgentId[tokenId] = agentId;

        ICryptoAIData(cryptoAiDataAddr).mintAgent(tokenId);
        emit NewToken(tokenId, agentId, _to);

        return agentId;
    }

    function _wrapMint(
        address _to,
        // string calldata _uri,
        // bytes calldata _data,
        // uint _fee,
        uint256 _squadId,
        uint256 _agentId
    ) internal returns (uint256) {
        TransferHelper.safeTransferFrom(
            feeTokenAddr,
            msg.sender,
            address(this),
            mintPrice
        );

        while (tokenIdToAgentId[_nextTokenId] > 0) {
            _nextTokenId++;
        }
        uint256 tokenId = _nextTokenId++;

        mint_(_to, tokenId, _agentId);

        if (_squadId != 0) {
            validateAgentBeforeMoveToSquad(_to, _agentId);

            ISquad(squadManager).moveAgentToSquad(
                msg.sender,
                tokenId,
                _squadId
            );
        }

        return tokenId;
    }

    /// @notice This function open minting role to public users
    function mint(
        address _to,
        // string calldata _uri,
        // bytes calldata _data,
        // uint _fee
        uint256 _agentId
    ) external returns (uint256) {
        return _wrapMint(_to, 0, _agentId);
    }

    function mint(
        address _to,
        // string calldata _uri,
        // bytes calldata _data,
        // uint _fee,
        uint256 _squadId,
        uint256 _agentId
    ) external nonReentrant returns (uint256) {
        return _wrapMint(_to, _squadId, _agentId);
    }

    function withdraw(address _to, uint _value) external onlyOwner {
        (bool success, ) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }

    function _validateURI(string calldata _uri) internal pure {
        if (bytes(_uri).length == 0) revert InvalidAgentData();
    }

    function updateAgentURI(
        uint256 _agentId,
        string calldata _uri
    ) external onlyAgentOwner(_agentId) {
        revert UriChangeNotAllowed();
    }

    function updateAgentData(
        uint256 _agentId,
        bytes calldata _sysPrompt,
        string calldata _promptKey,
        uint256 _promptIdx
    ) external onlyAgentOwner(_agentId) {
        _validateAgentData(_agentId, _promptKey, _sysPrompt, _promptIdx);

        emit AgentDataUpdate(
            _agentId,
            _promptIdx,
            datas[_agentId].sysPrompts[_promptKey][_promptIdx],
            _sysPrompt
        );

        datas[_agentId].sysPrompts[_promptKey][_promptIdx] = _sysPrompt;
    }

    function addNewAgentData(
        uint256 agentId,
        string calldata promptKey,
        bytes calldata sysPrompt
    ) external onlyAgentOwner(agentId) {
        if (sysPrompt.length == 0) revert InvalidAgentData();

        datas[agentId].sysPrompts[promptKey].push(sysPrompt);

        emit AgentDataAddNew(agentId, datas[agentId].sysPrompts[promptKey]);
    }


    function _checkUpdatePromptPermission(
        uint256 _agentId,
        string calldata _promptKey,
        bytes calldata _sysPrompt,
        uint256 _promptIdx,
        uint256 _randomNonce,
        bytes calldata _signature
    ) internal {
        address signer = recover(
            _agentId,
            _promptKey,
            _sysPrompt,
            _promptIdx,
            _randomNonce,
            _signature
        );

        _checkAgentOwner(signer, _agentId);
        if (signaturesUsed[signer][_signature]) revert SignatureUsed();
        signaturesUsed[signer][_signature] = true;
    }

    function _validateAgentData(
        uint256 _agentId,
        string memory _promptKey,
        bytes calldata _sysPrompt,
        uint256 _promptIdx
    ) internal view {
        if (_sysPrompt.length == 0) revert InvalidAgentData();
        uint256 len = datas[_agentId].sysPrompts[_promptKey].length;
        if (_promptIdx >= len) revert InvalidAgentPromptIndex();
    }

    function updateAgentDataWithSignature(
        uint256 _agentId,
        bytes calldata _sysPrompt,
        string calldata _promptKey,
        uint256 _promptIdx,
        uint256 _randomNonce,
        bytes calldata _signature
    ) external {
        _validateAgentData(_agentId, _promptKey, _sysPrompt, _promptIdx);
        _checkUpdatePromptPermission(
            _agentId,
            _promptKey,
            _sysPrompt,
            _promptIdx,
            _randomNonce,
            _signature
        );

        emit AgentDataUpdate(
            _agentId,
            _promptIdx,
            datas[_agentId].sysPrompts[_promptKey][_promptIdx],
            _sysPrompt
        );

        datas[_agentId].sysPrompts[_promptKey][_promptIdx] = _sysPrompt;
    }

    function updateAgentModelId(
        uint256 agentId,
        uint32 newModelId
    ) external onlyAgentOwner(agentId) {
        uint32 oldModelId = datas[agentId].modelId;
        datas[agentId].modelId = newModelId;
        emit AgentModelIdUpdate(agentId, oldModelId, newModelId);
    }


    // function _checkUpdateUriPermission(
    //     uint256 _agentId,
    //     string calldata _uri,
    //     uint256 _randomNonce,
    //     bytes calldata _signature
    // ) internal {
    //     address agentOwner = _ownerOf(_agentId);
    //     if (signaturesUsed[agentOwner][_signature]) revert SignatureUsed();

    //     address signer = recover(_agentId, _uri, _randomNonce, _signature);

    //     _checkAgentOwner(signer, _agentId);
    //     signaturesUsed[agentOwner][_signature] = true;
    // }

    function updateAgentUriWithSignature(
        uint256 _agentId,
        string calldata _uri,
        uint256 _randomNonce,
        bytes calldata _signature
    ) external {
        revert UriChangeNotAllowed();
    }

    function updateAgentFee(
        uint256 _agentId,
        uint256 _fee
    ) external onlyAgentOwner(_agentId) {
        if (datas[_agentId].fee != uint128(_fee)) {
            datas[_agentId].fee = uint128(_fee);
        }

        emit AgentFeeUpdate(_agentId, _fee);
    }

    function setStakingHub(address _stakingHub) external onlyOwner {
        stakingHub = _stakingHub;
    }

    function setWorkerHub(address _workerHub) external onlyOwner {
        workerHub = _workerHub;
    }

    function claimFee() external nonReentrant {
        uint256 totalFee = earnedFees[msg.sender];
        earnedFees[msg.sender] = 0;
        (bool success, ) = owner().call{value: totalFee}("");
        if (!success) revert FailedTransfer();

        emit FeesClaimed(msg.sender, totalFee);
    }

    function topUpPoolBalance(uint256 agentId, uint256 amount) external {
        TransferHelper.safeTransferFrom(feeTokenAddr, msg.sender, address(this), amount);
        poolBalance[agentId] += amount;

        emit TopUpPoolBalance(agentId, msg.sender, amount);
    }


    function getAgentFee(uint256 _agentId) external view returns (uint256) {
        return datas[_agentId].fee;
    }

    // function getAgentSystemPrompt(
    //     uint256 _agentId
    // ) external view returns (bytes[] memory) {
    //     return datas[_agentId].sysPrompts;
    // }

    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData,
        string calldata _promptKey,
        bool _flag,
        uint256 _feeAmount
    ) external nonReentrant {
        uint32 modelId = datas[_agentId].modelId;
        (uint256 estFeeWH, bytes memory fwdData) = _infer(
            modelId,
            _agentId,
            _calldata,
            _externalData,
            _promptKey,
            _feeAmount
        );

        TransferHelper.safeApprove(feeTokenAddr, workerHub, estFeeWH);
        uint256 inferId = IWorkerHub(workerHub).infer(
            modelId,
            fwdData,
            msg.sender,
            _flag
        );

        emit InferencePerformed(
            _agentId,
            msg.sender,
            fwdData,
            datas[_agentId].fee,
            _externalData,
            inferId
        );
    }

    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData,
        string calldata _promptKey,
        uint256 _feeAmount
    ) external nonReentrant {
        uint32 modelId = datas[_agentId].modelId;
        (uint256 estFeeWH, bytes memory fwdData) = _infer(
            modelId,
            _agentId,
            _calldata,
            _externalData,
            _promptKey,
            _feeAmount
        );

        TransferHelper.safeApprove(feeTokenAddr, workerHub, estFeeWH);

        uint256 inferId = IWorkerHub(workerHub).infer(
            modelId,
            fwdData,
            msg.sender
        );

        emit InferencePerformed(
            _agentId,
            msg.sender,
            fwdData,
            datas[_agentId].fee,
            _externalData,
            inferId
        );
    }

    function _infer(
        uint32 modelId,
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData,
        string calldata _promptKey,
        uint256 _feeAmount
    ) internal returns (uint256, bytes memory) {
        if (agentInfo[_agentId].status == AgentStatus.Empty) revert InvalidAgentData();
        if (_feeAmount < datas[_agentId].fee) revert InvalidAgentFee();

        bytes memory fwdData = abi.encodePacked(
            concatSystemPrompts(datas[_agentId].sysPrompts[_promptKey]),
            _calldata
        );
        uint256 estFeeWH = IStakingHub(stakingHub).getMinFeeToUse(modelId);

        address agentOwner = agentInfo[_agentId].owner;
        if (agentOwner == address(0)) {
            agentOwner = _ownerOf(agentInfo[_agentId].tokenId);
        }

        TransferHelper.safeTransferFrom(
            feeTokenAddr,
            msg.sender,
            address(this),
            _feeAmount
        );

        if (_feeAmount < estFeeWH && poolBalance[_agentId] >= estFeeWH) {
            unchecked {
                poolBalance[_agentId] -= estFeeWH;
            }
            if (_feeAmount > 0) {
                TransferHelper.safeTransfer(
                    feeTokenAddr,
                    agentOwner,
                    _feeAmount
                );
            }
        } else if (_feeAmount >= estFeeWH) {
            uint256 remain = _feeAmount - estFeeWH;
            if (remain > 0) {
                TransferHelper.safeTransfer(feeTokenAddr, agentOwner, remain);
            }
        } else {
            revert InsufficientFunds();
        }

        if (agentInfo[_agentId].status != AgentStatus.Empty && agentInfo[_agentId].status != AgentStatus.Unlocked) {
            agentRating[_agentId].totalPoints += 1;
        }

        return (estFeeWH, fwdData);
    }

    function getAgentId(uint256 _tokenId) external view returns (uint256) {
        return tokenIdToAgentId[_tokenId];
    }

    // function getAgentData(
    //     uint256 _agentId
    // ) external view returns (uint128 fee, bool isUsed, uint32 modelId, address promptScheduler) {
    //     IAI721Upgradeable.TokenMetaData storage d = datas[_agentId];
    //     fee = d.fee;
    //     isUsed = d.isUsed;
    //     modelId = d.modelId;
    //     promptScheduler = d.promptScheduler;
    // }

    function getAgentSysPrompts(
        uint256 _agentId,
        string calldata _promptKey
    ) external view returns (bytes[] memory) {
        return datas[_agentId].sysPrompts[_promptKey];
    }

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address, uint256) {
        return (
            _royaltyReceiver,
            (_salePrice * _royaltyPortion) / PORTION_DENOMINATOR
        );
    }

    function royaltyReceiver() external view returns (address) {
        return _royaltyReceiver;
    }

    function royaltyPortion() external view returns (uint16) {
        return _royaltyPortion;
    }

    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            IERC721MetadataUpgradeable
        ) returns (string memory) {
        uint256 _agentId = tokenIdToAgentId[_tokenId];
        if (_agentId == 0) revert InvalidAgentId();

        if (agentInfo[_agentId].status == AgentStatus.Empty) revert InvalidAgentData();
        ICryptoAIData cryptoAIDataContract = ICryptoAIData(cryptoAiDataAddr);
        return cryptoAIDataContract.tokenURI(_tokenId);
    }

    function supportsInterface(
        bytes4 _interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable,
            IERC165Upgradeable
        )
        returns (bool)
    {
        return
            _interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _batchSize
    )
        internal
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721PausableUpgradeable
        )
    {
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    function _burn(
        uint256 _tokenId
    ) internal 
        override
        (
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable
        )
    {
        super._burn(_tokenId);
    }

    function validateAgentBeforeMoveToSquad(
        address _user,
        uint256 _agentId
    ) public view {
        _checkAgentOwner(_user, _agentId);
        if (_agentId >= nextAgentId) revert InvalidAgentId();
    }

    function validateAgentsBeforeMoveToSquad(
        address _user,
        uint256[] calldata _agentIds
    ) external view {
        uint256 len = _agentIds.length;

        for (uint256 i = 0; i < len; i++) {
            _checkAgentOwner(_user, _agentIds[i]);
            if (_agentIds[i] >= nextAgentId) revert InvalidAgentId();
        }
    }

    function getAgentIdByOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        // only return minted agents
        uint256 len = balanceOf(_owner);
        uint256[] memory ids = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            ids[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return ids;
    }

    function updateMission(
        uint256 _agentId,
        uint256 _missionIdx,
        bytes calldata _missionData
    ) external onlyAgentOwner(_agentId) {
        if (
            _missionData.length == 0 ||
            _missionIdx >= missionsOf[_agentId].length ||
            _agentId >= nextAgentId
        ) revert InvalidAgentData();

        // emit AgentMissionUpdate(
        //     _agentId,
        //     _missionIdx,
        //     missionsOf[_agentId][_missionIdx],
        //     _missionData
        // );

        missionsOf[_agentId][_missionIdx] = _missionData;
    }

    function createMission(
        uint256 _agentId,
        bytes calldata _missionData
    ) external onlyAgentOwner(_agentId) {
        if (_missionData.length == 0 || _agentId >= nextAgentId)
            revert InvalidAgentData();
        missionsOf[_agentId].push(_missionData);

        // emit AgentMissionAddNew(_agentId, missionsOf[_agentId]);
    }

    function getMissionIdsByAgentId(
        uint256 _agentId
    ) external view returns (bytes[] memory) {
        return missionsOf[_agentId];
    }

    function setSquadManager(address _squadManager) external onlyOwner {
        if (_squadManager == address(0)) revert InvalidData();
        squadManager = _squadManager;
    }

    function setCryptoAiDataAddr(address _cryptoAiDataAddr) external onlyOwner {
        if (_cryptoAiDataAddr == address(0)) revert InvalidData();
        cryptoAiDataAddr = _cryptoAiDataAddr;
    }

    function _checkSquadManager() internal view {
        if (msg.sender != squadManager) revert Unauthorized();
    }

    modifier onlySquadManager() {
        _checkSquadManager();
        _;
    }

    function concatSystemPrompts(
        bytes[] memory sysPrompts
    ) internal pure returns (bytes memory) {

        uint256 len = sysPrompts.length;
        bytes memory concatedPrompt;

        for (uint256 i = 0; i < len; i++) {
            concatedPrompt = abi.encodePacked(
                concatedPrompt,
                sysPrompts[i],
                ";"
            );
        }

        return concatedPrompt;
    }

    function nextTokenId() external view override returns (uint256) {
        return _nextTokenId;
    }

    function recover(
        uint256 _agentId,
        string calldata _uri,
        uint256 _randomNonce,
        bytes calldata _signature
    ) internal view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                _uri,
                _agentId,
                _randomNonce,
                address(this),
                block.chainid
            )
        );
        bytes32 hash = ECDSAUpgradeable.toEthSignedMessageHash(structHash);
        return ECDSAUpgradeable.recover(hash, _signature);
    }

    function recover(
        uint256 _agentId,
        string calldata _promptKey,
        bytes calldata _sysPrompt,
        uint256 _promptIdx,
        uint256 _randomNonce,
        bytes calldata _signature
    ) internal view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                _agentId,
                _promptKey,
                _sysPrompt,
                _promptIdx,
                _randomNonce,
                address(this),
                block.chainid
            )
        );

        bytes32 hash = ECDSAUpgradeable.toEthSignedMessageHash(structHash);
        return ECDSAUpgradeable.recover(hash, _signature);
    }

    function unlockPFP(uint256 _tokenId) external {
        uint256 agentId = tokenIdToAgentId[_tokenId];
        if (agentId == 0) revert InvalidAgentId();
        if (msg.sender != _ownerOf(_tokenId)) revert Unauthorized();
        AgentRating storage a = agentRating[agentId];
        if (agentInfo[agentId].status != AgentStatus.Minted) revert InvalidData();
        if (a.totalPoints < NFT_UNLOCK_THRESHOLD) revert ThresholdNotReached();
        uint256 tokenId = agentInfo[agentId].tokenId;
        if (tokenId == 0) revert InvalidData();

        agentRating[agentId].unlockTime = uint64(block.timestamp);
        uint256 ra = this.getAgentRarity(tokenId);
        ICryptoAIData(cryptoAiDataAddr).unlockRenderAgent(tokenId);        
    }

    function isUnlockedAgent(uint256 _tokenId) public view returns (bool) {
        uint256 agentId = tokenIdToAgentId[_tokenId];
        if (agentId == 0) return false;
        return agentInfo[agentId].tokenId > 0;
        // return agentRating[_agentId].unlockTime > 0;
    }

    function getAgentRating(uint256 _agentId) external view returns (uint256, uint256) {
        AgentRating storage a = agentRating[_agentId];
        uint64 unlockTime = a.unlockTime;
        if (unlockTime == 0 && a.mintTime > 0) {
            unlockTime = uint64(block.timestamp);
        }
        return (a.totalPoints, unlockTime - a.mintTime);
    }

    function getAgentPendingRarity(uint256 _agentId) public view returns (uint256) {
        AgentRating storage a = agentRating[_agentId];
        uint256 x = a.totalPoints;
        uint256 timeUnit = 1 days;
        uint256 unlockTime = (a.mintTime > 0 && a.unlockTime == 0) ? uint64(block.timestamp) : a.unlockTime;
        uint256 y = (unlockTime - a.mintTime + timeUnit - 1) / timeUnit;

        uint256 gainedPoints = min(x * a1 / a2, MAX_RARITY * 30 / 100) + min(y * a3 / a4, MAX_RARITY * 20 / 100);
        uint256 lostPoints = b1 / (b2 * max(x * a1 / a2, MAX_RARITY * 30 / 100))
        + b3 / (b4 * max(y * a3 / a4, MAX_RARITY * 20 / 100));
        uint256 rarity = min(gainedPoints + MAX_RARITY * (30+20) / 100 - lostPoints, MAX_RARITY);
        
        return rarity;
    }

    function getAgentRarity(uint256 _tokenId) external view returns (uint256) {
        uint256 agentId = tokenIdToAgentId[_tokenId];
        if (agentId == 0) revert InvalidAgentId();
        AgentRating storage a = agentRating[agentId];
        if (!isUnlockedAgent(_tokenId)) revert InvalidData();
        
        return getAgentPendingRarity(agentId);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}

interface IMintableAgent {
    function isUnlockedAgent(uint256 tokenId) external view returns (bool);
    function getAgentRating(uint256 tokenId) external view returns (uint256, uint256);
    function getAgentRarity(uint256 tokenId) external view returns (uint256);
}

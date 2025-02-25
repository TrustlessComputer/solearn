// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable, ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IRealWorldAgent} from "./IRealWorldAgent.sol";
import {IHybridGateway} from "../real-world/interfaces/IHybridGateway.sol";

contract RealWorldAgentUpgradeable is
    IRealWorldAgent,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    using SafeERC20 for IERC20;

    bytes32 private constant SIGN_DATA_TYPEHASH = keccak256("REAL_WORLD_AGENT");
    // check duplicate uuid
    // uuid => promptId
    mapping(bytes32 => uint256) private _uuids;
    IHybridGateway private _gateway;

    uint256[50] private __gap;

    struct SignData {
        bytes32 uuid;
        bytes data;
    }

    modifier notZeroAddress(address addr) {
        _validateAddress(addr);
        _;
    }

    function initialize(
        string memory name_,
        string memory version_,
        IHybridGateway gateway_
    ) external initializer {
        __Ownable_init();
        __EIP712_init_unchained(name_, version_);

        _validateAddress(address(gateway_));

        _gateway = gateway_;
    }

    function act(
        bytes32 uuid,
        bytes calldata executeData
    ) external returns (uint256) {
        // Extract signature from the end of external data (last 65 bytes)
        uint256 dataLength = executeData.length;
        if (dataLength < 65) revert InvalidExternalDataLength();

        bytes calldata data = executeData[:(dataLength - 65)];
        bytes memory signature = executeData[(dataLength - 65):];

        return act(uuid, data, signature);
    }

    function act(
        bytes32 uuid,
        bytes calldata data,
        bytes memory signature
    ) public payable returns (uint256) {
        if (_uuids[uuid] != 0) revert DuplicateUuid();
        _uuids[uuid] = 1;

        // Extract signer address from signature using ecrecover
        bytes32 messageHash = getHashToSign(uuid, data);
        address signer = ECDSAUpgradeable.recover(messageHash, signature);
        uint256 actId = _gateway.infer{value: msg.value}(data, signer);
        _uuids[uuid] = actId;   

        emit ExecutionRequested(actId, uuid, signer, data);

        return actId;
    }

    function getPromptId(bytes32 uuid) external view returns (uint256) {
        if (_uuids[uuid] == 0) revert InvalidUuid();

        return _uuids[uuid];
    }

    function getHashToSign(
        bytes32 uuid,
        bytes memory data
    ) public view virtual returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(SIGN_DATA_TYPEHASH, SignData({uuid: uuid, data: data}))
        );

        return _hashTypedDataV4(structHash);
    }

    function _validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }
}

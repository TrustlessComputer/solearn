// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable, ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IRealWorldAgent} from "./IRealWorldAgent.sol";

contract RealWorldAgentUpgradeable is
    IRealWorldAgent,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    using SafeERC20 for IERC20;

    bytes32 private constant SIGN_DATA_TYPEHASH = keccak256("REAL_WORLD_AGENT");

    uint256 private _minFeeToUse;
    uint256 private _currentActId;
    // check duplicate uuid
    mapping(bytes32 => uint256) private _uuids;
    address private _worker;
    uint32 private _timeout;
    mapping(uint256 => Request) private _requests;
    IERC20 private _tokenFee;

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
        uint256 minFeeToUse_,
        uint32 timeout_,
        IERC20 tokenFee_,
        address worker_
    ) external initializer {
        __Ownable_init();
        __EIP712_init_unchained(name_, version_);

        _validateAddress(worker_);

        _minFeeToUse = minFeeToUse_;
        _timeout = timeout_;
        _tokenFee = tokenFee_;
        _worker = worker_;
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
    ) public returns (uint256) {
        if (_uuids[uuid] != 0) revert DuplicateUuid();
        uint256 actId = ++_currentActId;
        _uuids[uuid] = actId;

        // safe transfer from user to this contract
        if (_minFeeToUse > 0) {
            _tokenFee.safeTransferFrom(msg.sender, _worker, _minFeeToUse);
        }

        // Extract signer address from signature using ecrecover
        bytes32 messageHash = getHashToSign(uuid, data);
        address signer = ECDSAUpgradeable.recover(messageHash, signature);
        emit ExecutionRequested(actId, uuid, signer, data);

        // store request
        _requests[actId] = Request({
            uuid: uuid,
            data: data,
            creator: signer,
            timeout: uint32(block.timestamp + _timeout),
            result: new bytes(0),
            status: RequestStatus.PENDING
        });

        return actId;
    }

    function submitSolution(uint256 actId, bytes calldata result) external {
        Request storage request = _requests[actId];
        if (request.status != RequestStatus.PENDING)
            revert InvalidRequestStatus();
        if (block.timestamp > request.timeout) revert Timeout();
        if (msg.sender != _worker) revert Unauthorized();

        request.result = result;
        request.status = RequestStatus.EXECUTED;

        emit SolutionSubmitted(actId, msg.sender, request.result);
    }

    function setWorker(
        address newWorker
    ) external onlyOwner notZeroAddress(newWorker) {
        emit WorkerUpdated(_worker, newWorker);
        _worker = newWorker;
    }

    function setTokenFee(
        IERC20 tokenFee_
    ) external onlyOwner notZeroAddress(address(tokenFee_)) {
        _tokenFee = tokenFee_;
    }

    function setMinFeeToUse(uint256 minFeeToUse_) external onlyOwner {
        _minFeeToUse = minFeeToUse_;
    }

    function setTimeout(uint32 timeout_) external onlyOwner {
        _timeout = timeout_;
    }

    function withdrawFeeToken(address to, uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (amount > _tokenFee.balanceOf(address(this)))
            revert InsufficientBalance();

        _tokenFee.safeTransfer(to, amount);
    }

    function getResultById(bytes32 uuid) external view returns (bytes memory) {
        if (_uuids[uuid] == 0) revert InvalidUuid();

        return _requests[_uuids[uuid]].result;
    }

    function getActId() external view returns (uint256) {
        return _currentActId;
    }

    function getRequest(uint256 actId) external view returns (Request memory) {
        return _requests[actId];
    }

    function getMinFeeToUse() external view returns (uint256) {
        return _minFeeToUse;
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

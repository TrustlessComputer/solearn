// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712, ECDSA} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IRealWorldAgent} from "./IRealWorldAgent.sol";

abstract contract RealWorldAgent is IRealWorldAgent, Ownable, EIP712 {
    using SafeERC20 for IERC20;

    uint256 private _minFeeToUse;
    uint256 private _nextActId;
    // check duplicate uuid
    mapping(bytes32 => uint256) private _uuids;
    address private _worker;
    uint32 private _timeout;
    mapping(uint256 => Request) private _requests;
    IERC20 private _tokenFee;

    modifier notZeroAddress(address addr) {
        _validateAddress(addr);
        _;
    }

    constructor(
        uint256 minFeeToUse_,
        uint32 timeout_,
        IERC20 tokenFee_
    ) Ownable() {
        _minFeeToUse = minFeeToUse_;
        _timeout = timeout_;
        _nextActId = 0;
        _tokenFee = tokenFee_;
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
        uint256 actId = ++_nextActId;
        _uuids[uuid] = actId;

        // safe transfer from user to this contract
        if (_minFeeToUse > 0) {
            _tokenFee.safeTransferFrom(msg.sender, address(this), _minFeeToUse);
        }

        // Extract signer address from signature using ecrecover
        bytes32 messageHash = getHashToSign(uuid, data);
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        address signer = ECDSA.recover(messageHash, v, r, s);
        if (signer == address(0)) revert InvalidSignature();

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
        return _nextActId;
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
            abi.encode(
                keccak256("Data(bytes32 uuid,bytes data)"),
                uuid,
                keccak256(data)
            )
        );

        return _hashTypedDataV4(structHash);
    }

    function _validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }
}

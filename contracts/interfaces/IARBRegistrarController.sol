// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct ReferralInfo {
    address referrerAddress;
    bytes32 referrerNodehash;
    uint256 referralAmount;
    uint256 signedAt;
    bytes signature;
}

interface IARBRegistrarController {
    function bulkRegister(string[] calldata names, address owner, uint duration, address resolver, bool isUseGiftCard, bool isSetPrimaryName, ReferralInfo memory referralInfo) external payable;

    function renew(string calldata name, uint256 duration) external payable;
}

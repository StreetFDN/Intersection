// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VeToken.sol";

contract VeStreet is VeToken {
    constructor(address streetToken, uint256 maxLockTime)
        VeToken(streetToken, maxLockTime)
    {}
}
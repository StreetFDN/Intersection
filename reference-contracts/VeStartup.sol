// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VeToken.sol";

contract VeStartup is VeToken {
    constructor(address startupToken, uint256 maxLockTime)
        VeToken(startupToken, maxLockTime)
    {}
}
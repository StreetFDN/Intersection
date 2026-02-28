// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IStreetToken} from "./interfaces/IStreetToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title StreetToken
/// @author Street Protocol (Aerodrome fork)
/// @notice The native token in the Street Protocol ecosystem
/// @dev Emitted by the Minter
contract StreetToken is IStreetToken, ERC20Permit {
    address public minter;
    address private owner;

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    constructor() ERC20("Street Protocol Token", "STREET") ERC20Permit("Street Protocol Token") {
        minter = msg.sender;
        owner = msg.sender;
    }

    /// @dev No checks as its meant to be once off to set minting rights to Minter
    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }

    function mint(address account, uint256 amount) external returns (bool) {
        if (msg.sender != minter) revert NotMinter();
        _mint(account, amount);
        return true;
    }
}

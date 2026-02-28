// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DemoUSD is ERC20, Ownable {
    constructor(address initialOwner)
        ERC20("Demo USD", "DUSD")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

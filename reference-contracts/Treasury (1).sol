// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Treasury is Ownable, ReentrancyGuard {
    IERC20 public immutable token;

    address public distributor;
    address public streetDAO;

    event DistributorSet(address indexed distributor);
    event StreetDAOSet(address indexed streetDAO);
    event Withdraw(address indexed by, address indexed to, uint256 amount);

    constructor(address token_, address distributor_, address streetDAO_, address initialOwner_) Ownable(initialOwner_) {
        require(token_ != address(0), "token=0");
        require(initialOwner_ != address(0), "owner=0");
        token = IERC20(token_);
        distributor = distributor_;
        streetDAO = streetDAO_;

        if (distributor_ != address(0)) emit DistributorSet(distributor_);
        if (streetDAO_ != address(0)) emit StreetDAOSet(streetDAO_);
    }

    modifier onlyDistributorOrStreetDAO() {
        require(msg.sender == distributor || msg.sender == streetDAO, "not authorized");
        _;
    }

    function setDistributor(address distributor_) external onlyOwner {
        require(distributor_ != address(0), "distributor=0");
        require(distributor == address(0), "distributor already set");
        distributor = distributor_;
        emit DistributorSet(distributor_);
    }

    function setStreetDAO(address streetDAO_) external onlyOwner {
        require(streetDAO_ != address(0), "streetDAO=0");
        require(streetDAO == address(0), "streetDAO already set");
        streetDAO = streetDAO_;
        emit StreetDAOSet(streetDAO_);
    }

    function withdraw(address to, uint256 amount) external onlyDistributorOrStreetDAO nonReentrant {
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");

        bool ok = token.transfer(to, amount);
        require(ok, "transfer failed");

        emit Withdraw(msg.sender, to, amount);
    }

    function balance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

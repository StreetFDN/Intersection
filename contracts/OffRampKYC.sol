// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title OffRampKYC
/// @notice KYC verification for fiat off-ramps only (not on-chain trading).
/// @dev Optional v1; integrate with Civic or similar provider later.
contract OffRampKYC is Ownable {
    address public civicGateway;

    mapping(address => bool) public kycApproved;

    event KYCApproved(address indexed user);
    event KYCRevoked(address indexed user);
    event CivicGatewaySet(address indexed gateway);

    constructor() Ownable() {}

    function setCivicGateway(address _civicGateway) external onlyOwner {
        if (_civicGateway == address(0)) revert ZeroAddress();
        civicGateway = _civicGateway;
        emit CivicGatewaySet(_civicGateway);
    }

    /// @notice Check KYC status (called by off-ramp contracts).
    function isKYCApproved(address user) external view returns (bool) {
        return kycApproved[user];
    }

    /// @notice Approve KYC (owner or Civic gateway).
    function approveKYC(address user) external {
        if (msg.sender != civicGateway && msg.sender != owner()) revert NotAuthorized();
        kycApproved[user] = true;
        emit KYCApproved(user);
    }

    /// @notice Revoke KYC (owner or Civic gateway).
    function revokeKYC(address user) external {
        if (msg.sender != civicGateway && msg.sender != owner()) revert NotAuthorized();
        kycApproved[user] = false;
        emit KYCRevoked(user);
    }

    error NotAuthorized();
    error ZeroAddress();
}

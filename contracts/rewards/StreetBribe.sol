// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {BribeVotingReward} from "./BribeVotingReward.sol";
import {ProtocolTimeLibrary} from "../libraries/ProtocolTimeLibrary.sol";

/// @notice Street bribes: 5% platform fee to treasury, rest to voters (same as BribeVotingReward).
contract StreetBribe is BribeVotingReward {
    using SafeERC20 for IERC20;

    error ZeroAddress();

    /// @notice 5% = 500 basis points
    uint256 public constant PLATFORM_FEE = 500;
    /// @notice Recipient of platform fee
    address public immutable treasury;

    constructor(
        address _forwarder,
        address _voter,
        address[] memory _rewards,
        address _treasury
    ) BribeVotingReward(_forwarder, _voter, _rewards) {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    /// @dev Takes 5% fee to treasury, 95% to bribe rewards.
    function notifyRewardAmount(address token, uint256 amount) external override nonReentrant {
        address sender = _msgSender();

        if (!isReward[token]) {
            if (!IVoter(voter).isWhitelistedToken(token)) revert NotWhitelisted();
            isReward[token] = true;
            rewards.push(token);
        }

        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(sender, address(this), amount);

        uint256 fee = (amount * PLATFORM_FEE) / 10_000;
        uint256 netAmount = amount - fee;
        if (fee > 0) IERC20(token).safeTransfer(treasury, fee);

        uint256 epochStart = ProtocolTimeLibrary.epochStart(block.timestamp);
        tokenRewardsPerEpoch[token][epochStart] += netAmount;

        emit NotifyReward(sender, token, epochStart, netAmount);
    }
}

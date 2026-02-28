// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IMinter} from "./interfaces/IMinter.sol";
import {IStreetToken} from "./interfaces/IStreetToken.sol";
import {Minter} from "./Minter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Street Protocol Minter
/// @notice Minter with fixed emissions schedule (100M Y1, 80M Y2, 60M Y3–Y4, 5M/year tail). No rebases.
contract StreetMinter is Minter {
    using SafeERC20 for IStreetToken;
    /// @notice Week 1–52: 100M STREET / 52
    uint256 public constant YEAR_1_WEEKLY = 1_923_077 * 1e18;
    /// @notice Week 53–104: 80M / 52
    uint256 public constant YEAR_2_WEEKLY = 1_538_462 * 1e18;
    /// @notice Week 105–156: 60M / 52
    uint256 public constant YEAR_3_WEEKLY = 1_153_846 * 1e18;
    /// @notice Week 157–208: 60M / 52
    uint256 public constant YEAR_4_WEEKLY = 1_153_846 * 1e18;
    /// @notice Week 209+: 5M / 52 (tail)
    uint256 public constant TAIL_EMISSION = 96_154 * 1e18;

    /// @notice Start of emission schedule (start of week at deployment).
    uint256 public immutable initialTimestamp;

    constructor(
        address _voter,
        address _ve,
        address _rewardsDistributor
    ) Minter(_voter, _ve, _rewardsDistributor) {
        initialTimestamp = (block.timestamp / WEEK) * WEEK;
    }

    /// @notice Weekly emission for the current week based on schedule (no rebases).
    function weeklyEmission() public view returns (uint256) {
        uint256 epoch = (block.timestamp - initialTimestamp) / WEEK;
        if (epoch < 52) return YEAR_1_WEEKLY;
        if (epoch < 104) return YEAR_2_WEEKLY;
        if (epoch < 156) return YEAR_3_WEEKLY;
        if (epoch < 208) return YEAR_4_WEEKLY;
        return TAIL_EMISSION;
    }

    /// @inheritdoc IMinter
    /// @dev Uses fixed schedule; no rebases (no transfer to rewardsDistributor).
    function updatePeriod() external override returns (uint256 _period) {
        _period = activePeriod;
        if (block.timestamp >= _period + WEEK) {
            epochCount++;
            _period = (block.timestamp / WEEK) * WEEK;
            activePeriod = _period;

            uint256 _emission = weeklyEmission();
            uint256 _rate = teamRate;
            uint256 _teamEmissions = (_rate * _emission) / (MAX_BPS - _rate);
            uint256 _required = _emission + _teamEmissions;
            uint256 _balanceOf = streetToken.balanceOf(address(this));
            if (_balanceOf < _required) {
                streetToken.mint(address(this), _required - _balanceOf);
            }

            streetToken.safeTransfer(address(team), _teamEmissions);
            streetToken.safeApprove(address(voter), _emission);
            voter.notifyRewardAmount(_emission);

            emit Mint(msg.sender, _emission, streetToken.totalSupply(), _emission == TAIL_EMISSION);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IVotingRewardsFactory} from "../interfaces/factories/IVotingRewardsFactory.sol";
import {FeesVotingReward} from "../rewards/FeesVotingReward.sol";
import {StreetBribe} from "../rewards/StreetBribe.sol";

/// @notice Creates FeesVotingReward and StreetBribe (5% fee to treasury) for each gauge.
contract StreetVotingRewardsFactory is IVotingRewardsFactory {
    address public immutable treasury;

    constructor(address _treasury) {
        treasury = _treasury;
    }

    /// @inheritdoc IVotingRewardsFactory
    function createRewards(
        address _forwarder,
        address[] memory _rewards
    ) external returns (address feesVotingReward, address bribeVotingReward) {
        feesVotingReward = address(new FeesVotingReward(_forwarder, msg.sender, _rewards));
        bribeVotingReward = address(new StreetBribe(_forwarder, msg.sender, _rewards, treasury));
    }
}

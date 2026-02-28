// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IVoter} from "./interfaces/IVoter.sol";
import {Voter} from "./Voter.sol";

/// @title Street Protocol Voter
/// @notice Voter with founder whitelist for gauge creation and gauge pause (founder or governor).
contract StreetVoter is Voter {
    constructor(address _forwarder, address _ve, address _factoryRegistry) Voter(_forwarder, _ve, _factoryRegistry) {}

    /// @dev Only whitelisted founders or governor may create gauges.
    function _requireCanCreateGauge(address sender, bool, address, address) internal view override {
        if (!whitelistedFounders[sender] && sender != governor) revert NotWhitelisted();
    }
}

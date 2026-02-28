// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {StreetMinter} from "contracts/StreetMinter.sol";

contract StreetMinterTest is BaseTest {
    function testWeeklyEmissionSchedule() public {
        StreetMinter sm = StreetMinter(address(minter));
        assertEq(sm.initialTimestamp(), (block.timestamp / 1 weeks) * 1 weeks);
        assertEq(sm.weeklyEmission(), sm.YEAR_1_WEEKLY());

        // Year 2 (epoch 52)
        vm.warp(sm.initialTimestamp() + 52 * 1 weeks);
        assertEq(sm.weeklyEmission(), sm.YEAR_2_WEEKLY());

        // Year 3 (epoch 104)
        vm.warp(sm.initialTimestamp() + 104 * 1 weeks);
        assertEq(sm.weeklyEmission(), sm.YEAR_3_WEEKLY());

        // Year 4 (epoch 156)
        vm.warp(sm.initialTimestamp() + 156 * 1 weeks);
        assertEq(sm.weeklyEmission(), sm.YEAR_4_WEEKLY());

        // Tail (epoch 208+)
        vm.warp(sm.initialTimestamp() + 208 * 1 weeks);
        assertEq(sm.weeklyEmission(), sm.TAIL_EMISSION());
    }

    function testUpdatePeriodMintsAndDistributesToVoter() public {
        StreetMinter sm = StreetMinter(address(minter));
        skip(1 weeks); // move past first period so updatePeriod can mint
        uint256 balanceBefore = STREET.balanceOf(address(voter));
        minter.updatePeriod();
        assertEq(minter.epochCount(), 1);
        uint256 balanceAfter = STREET.balanceOf(address(voter));
        // Full weekly emission goes to voter; team gets an additional share
        assertGt(balanceAfter, balanceBefore);
        assertApproxEqAbs(balanceAfter - balanceBefore, sm.YEAR_1_WEEKLY(), 1e18);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {FounderControls} from "contracts/FounderControls.sol";

contract FounderControlsTest is Test {
    FounderControls fc;
    address pool;
    address founder;
    address other;

    function setUp() public {
        fc = new FounderControls();
        pool = makeAddr("pool");
        founder = makeAddr("founder");
        other = makeAddr("other");
        fc.registerFounder(pool, founder);
    }

    function test_registerFounder_onlyOwner() public {
        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        fc.registerFounder(makeAddr("pool2"), other);
    }

    function test_setPaused_onlyFounder() public {
        vm.prank(other);
        vm.expectRevert(FounderControls.NotFounder.selector);
        fc.setPaused(pool, true);
    }

    function test_setPaused_founderCanPause() public {
        vm.prank(founder);
        fc.setPaused(pool, true);
        assertTrue(fc.paused(pool));
        vm.prank(founder);
        fc.setPaused(pool, false);
        assertFalse(fc.paused(pool));
    }

    function test_checkSwap_returnsFalseWhenPaused() public {
        vm.prank(founder);
        fc.setPaused(pool, true);
        assertFalse(fc.checkSwap(pool, 100));
    }

    function test_checkSwap_returnsTrueWhenNotPaused() public {
        assertTrue(fc.checkSwap(pool, 100));
    }

    function test_setMaxFloat_onlyFounder() public {
        vm.prank(other);
        vm.expectRevert(FounderControls.NotFounder.selector);
        fc.setMaxFloat(pool, 5000);
    }

    function test_setMaxFloat_invalidBps() public {
        vm.prank(founder);
        vm.expectRevert(FounderControls.InvalidBps.selector);
        fc.setMaxFloat(pool, 10_001);
    }

    function test_setMaxFloat_founderCanSet() public {
        vm.prank(founder);
        fc.setMaxFloat(pool, 5000);
        assertEq(fc.maxFloatBps(pool), 5000);
    }

    function test_setMaxDailyVolume_onlyFounder() public {
        vm.prank(other);
        vm.expectRevert(FounderControls.NotFounder.selector);
        fc.setMaxDailyVolume(pool, 1e18);
    }

    function test_setMaxDailyVolume_andCheckSwap() public {
        vm.prank(founder);
        fc.setMaxDailyVolume(pool, 100);
        assertTrue(fc.checkSwap(pool, 50));
        assertTrue(fc.checkSwap(pool, 50));
        assertFalse(fc.checkSwap(pool, 1));
    }

    function test_dailyVolume_resetsAfterOneDay() public {
        vm.prank(founder);
        fc.setMaxDailyVolume(pool, 100);
        assertTrue(fc.checkSwap(pool, 99));
        vm.warp(block.timestamp + 1 days);
        assertTrue(fc.checkSwap(pool, 99));
    }
}

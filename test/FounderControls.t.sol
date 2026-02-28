// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {FounderControls} from "contracts/FounderControls.sol";
import {MockERC20} from "./utils/MockERC20.sol";

/// @dev Minimal mock pool exposing token0/token1 for float-limit tests.
contract MockPool {
    address public token0;
    address public token1;

    constructor(address _t0, address _t1) {
        token0 = _t0;
        token1 = _t1;
    }
}

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

    // ── registerFounder ──────────────────────────────────────────

    function test_registerFounder_onlyOwner() public {
        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        fc.registerFounder(makeAddr("pool2"), other);
    }

    function test_registerFounder_revertsOnZeroPool() public {
        vm.expectRevert(FounderControls.ZeroAddress.selector);
        fc.registerFounder(address(0), founder);
    }

    function test_registerFounder_revertsOnZeroFounder() public {
        vm.expectRevert(FounderControls.ZeroAddress.selector);
        fc.registerFounder(makeAddr("pool3"), address(0));
    }

    // ── setPaused ────────────────────────────────────────────────

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

    // ── checkSwap – pause & volume ──────────────────────────────

    function test_checkSwap_returnsFalseWhenPaused() public {
        vm.prank(founder);
        fc.setPaused(pool, true);
        assertFalse(fc.checkSwap(pool, 100));
    }

    function test_checkSwap_returnsTrueWhenNotPaused() public {
        assertTrue(fc.checkSwap(pool, 100));
    }

    // ── setMaxFloat ──────────────────────────────────────────────

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

    // ── setMaxDailyVolume ────────────────────────────────────────

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

    // ── checkSwap – float limit ─────────────────────────────────

    function test_checkSwap_floatLimit_blocksWhenExceeded() public {
        // Deploy real ERC20 tokens and a mock pool
        MockERC20 tokenA = new MockERC20("A", "A", 18);
        MockERC20 tokenB = new MockERC20("B", "B", 18);
        MockPool mockPool = new MockPool(address(tokenA), address(tokenB));

        // Register founder for the mock pool
        fc.registerFounder(address(mockPool), founder);

        // Set float limit to 50% (5000 bps)
        vm.prank(founder);
        fc.setMaxFloat(address(mockPool), 5000);

        // Token total supplies = 1000e18 each
        deal(address(tokenA), address(this), 1000e18);
        deal(address(tokenB), address(this), 1000e18);

        // Pool holds 600e18 of tokenA (60% > 50%) → should fail
        deal(address(tokenA), address(mockPool), 600e18);
        deal(address(tokenB), address(mockPool), 400e18);

        assertFalse(fc.checkSwap(address(mockPool), 0));
    }

    function test_checkSwap_floatLimit_allowsWhenWithinLimit() public {
        MockERC20 tokenA = new MockERC20("A", "A", 18);
        MockERC20 tokenB = new MockERC20("B", "B", 18);
        MockPool mockPool = new MockPool(address(tokenA), address(tokenB));

        fc.registerFounder(address(mockPool), founder);

        vm.prank(founder);
        fc.setMaxFloat(address(mockPool), 5000);

        // Token total supplies = 1000e18 each
        deal(address(tokenA), address(this), 1000e18);
        deal(address(tokenB), address(this), 1000e18);

        // Pool holds 400e18 of each (40% < 50%) → should pass
        deal(address(tokenA), address(mockPool), 400e18);
        deal(address(tokenB), address(mockPool), 400e18);

        assertTrue(fc.checkSwap(address(mockPool), 0));
    }

    function test_checkSwap_floatLimit_boundaryExactlyAtLimit() public {
        MockERC20 tokenA = new MockERC20("A", "A", 18);
        MockERC20 tokenB = new MockERC20("B", "B", 18);
        MockPool mockPool = new MockPool(address(tokenA), address(tokenB));

        fc.registerFounder(address(mockPool), founder);

        vm.prank(founder);
        fc.setMaxFloat(address(mockPool), 5000);

        // Token total supplies = 1000e18 each
        deal(address(tokenA), address(this), 1000e18);
        deal(address(tokenB), address(this), 1000e18);

        // Pool holds exactly 50% → reserve * 10_000 == maxBps * supply → should pass
        deal(address(tokenA), address(mockPool), 500e18);
        deal(address(tokenB), address(mockPool), 500e18);

        assertTrue(fc.checkSwap(address(mockPool), 0));
    }

    function test_checkSwap_noFloatLimit_skipsCheck() public {
        // maxFloatBps defaults to 0 → no float check
        assertTrue(fc.checkSwap(pool, 0));
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {StreetBribe} from "contracts/rewards/StreetBribe.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StreetBribeTest is BaseTest {
    function testPlatformFeeSentToTreasury() public {
        StreetBribe bribe = StreetBribe(payable(voter.gaugeToBribe(address(gauge))));
        assertEq(bribe.PLATFORM_FEE(), 500);
        assertEq(bribe.treasury(), treasury);

        uint256 amount = 1000 * 1e18;
        deal(address(LR), address(owner), amount);
        vm.startPrank(address(owner));
        owner.approve(address(LR), address(bribe), amount);
        bribe.notifyRewardAmount(address(LR), amount);
        vm.stopPrank();

        uint256 expectedFee = (amount * 500) / 10_000;
        assertEq(IERC20(LR).balanceOf(treasury), expectedFee);
        assertEq(IERC20(LR).balanceOf(address(bribe)), amount - expectedFee);
    }
}

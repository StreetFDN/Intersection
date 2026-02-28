// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {IStreetToken} from "contracts/interfaces/IStreetToken.sol";

contract StreetTokenTest is BaseTest {
    StreetToken token;

    function _setUp() public override {
        token = new StreetToken();
    }

    function testCannotSetMinterIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IStreetToken.NotMinter.selector);
        token.setMinter(address(owner3));
    }

    function testSetMinter() public {
        token.setMinter(address(owner3));

        assertEq(token.minter(), address(owner3));
    }

    function testCannotMintIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IStreetToken.NotMinter.selector);
        token.mint(address(owner2), TOKEN_1);
    }

    function testNameAndSymbol() public {
        assertEq(token.name(), "Street Protocol Token");
        assertEq(token.symbol(), "STREET");
    }

    function testMaxSupply() public {
        assertEq(token.MAX_SUPPLY(), 1_000_000_000e18);
    }
}

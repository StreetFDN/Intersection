// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {OffRampKYC} from "contracts/OffRampKYC.sol";

contract OffRampKYCTest is Test {
    OffRampKYC kyc;
    address gateway;
    address user;

    function setUp() public {
        kyc = new OffRampKYC();
        gateway = makeAddr("gateway");
        user = makeAddr("user");
        kyc.setCivicGateway(gateway);
    }

    function test_ownerCanApproveKYC() public {
        kyc.approveKYC(user);
        assertTrue(kyc.kycApproved(user));
        assertTrue(kyc.isKYCApproved(user));
    }

    function test_gatewayCanApproveKYC() public {
        vm.prank(gateway);
        kyc.approveKYC(user);
        assertTrue(kyc.kycApproved(user));
    }

    function test_otherCannotApproveKYC() public {
        vm.prank(user);
        vm.expectRevert(OffRampKYC.NotAuthorized.selector);
        kyc.approveKYC(user);
    }

    function test_ownerCanRevokeKYC() public {
        kyc.approveKYC(user);
        kyc.revokeKYC(user);
        assertFalse(kyc.kycApproved(user));
    }

    function test_gatewayCanRevokeKYC() public {
        kyc.approveKYC(user);
        vm.prank(gateway);
        kyc.revokeKYC(user);
        assertFalse(kyc.kycApproved(user));
    }

    function test_setCivicGateway_revertsOnZeroAddress() public {
        vm.expectRevert(OffRampKYC.ZeroAddress.selector);
        kyc.setCivicGateway(address(0));
    }
}

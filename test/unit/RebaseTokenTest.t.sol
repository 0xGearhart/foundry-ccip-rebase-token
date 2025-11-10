// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract RebaseTokenTest is Test, CodeConstants {
    RebaseToken public rbt;
    uint256 constant HIGHER_INTEREST_RATE = 9e10;

    function setUp() external {
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
    }

    function testSetInterestRateFailsWhenIncreased() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyBeDecreased.selector,
                INITIAL_INTEREST_RATE,
                HIGHER_INTEREST_RATE
            )
        );
        rbt.setInterestRate(HIGHER_INTEREST_RATE);
    }
}

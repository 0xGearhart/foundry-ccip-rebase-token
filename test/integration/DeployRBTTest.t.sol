// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DeployRBT} from "../../script/DeployRBT.s.sol";
import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployRBTTest is Test, CodeConstants {
    DeployRBT public deployer;
    HelperConfig public helperConfig;
    RebaseToken public rbt;

    function setUp() external {
        deployer = new DeployRBT();
        (rbt) = deployer.run();
        // (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                           INITIAL DSC STATE
    //////////////////////////////////////////////////////////////*/

    function testRbtNameWasSetCorrectly() external view {
        assertEq(rbt.name(), RBT_NAME);
    }

    function testRbtSymbolWasSetCorrectly() external view {
        assertEq(rbt.symbol(), RBT_SYMBOL);
    }

    function testRbtInitialInterestRateWasSetCorrectly() external view {
        assertEq(rbt.getGlobalInterestRate(), INITIAL_INTEREST_RATE);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

contract DeployRBT is Script, CodeConstants {
    function run() external returns (RebaseToken) {
        return deployContract();
    }

    function deployContract() public returns (RebaseToken rbt) {
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
    }
}

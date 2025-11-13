// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

contract DeployRBT is Script, CodeConstants {
    function run() external returns (RebaseToken rbt, Vault vault) {
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
        vault = new Vault(rbt);
        rbt.grantMintAndBurnRole(address(vault));
    }
}

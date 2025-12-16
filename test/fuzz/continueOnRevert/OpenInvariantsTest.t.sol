// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DeployRBT} from "../../../script/DeployRBT.s.sol";
import {RebaseToken} from "../../../src/RebaseToken.sol";
import {Vault} from "../../../src/Vault.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DeployRBT public deployer;
    // Handler public handler;
    RebaseToken rbt;
    Vault vault;

    function setUp() external {
        deployer = new DeployRBT();
        (vault, rbt,,) = deployer.run(true);
        // handler = new Handler(rbt, vault);

        // targetContract(address(handler));
    }
    // function invariant_() public pure {}
}

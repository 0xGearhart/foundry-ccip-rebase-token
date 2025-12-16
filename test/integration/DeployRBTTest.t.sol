// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants, DeployRBT} from "../../script/DeployRBT.s.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployRBTTest is Test, CodeConstants {
    DeployRBT public deployer;
    RebaseToken public rbt;
    Vault public vault;

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    function setUp() external {
        deployer = new DeployRBT();
        (vault, rbt,,) = deployer.run(true);
    }

    /*//////////////////////////////////////////////////////////////
                           INITIAL RBT STATE
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

    function testRbtGrantedMintAndBurnRoleToVaultContract() external view {
        assertEq(rbt.hasRole(MINT_AND_BURN_ROLE, address(vault)), true);
    }

    /*//////////////////////////////////////////////////////////////
                          INITIAL VAULT STATE
    //////////////////////////////////////////////////////////////*/

    function testVaultRbtAddressWasSetCorrectly() external view {
        assertEq(vault.getRebaseTokenAddress(), address(rbt));
    }
}

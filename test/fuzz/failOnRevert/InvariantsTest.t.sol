// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DeployRBT} from "../../../script/DeployRBT.s.sol";
import {RebaseToken} from "../../../src/RebaseToken.sol";
import {Vault} from "../../../src/Vault.sol";
import {Handler} from "./Handler.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployRBT public deployer;
    Handler public handler;
    RebaseToken rbt;
    Vault vault;

    function setUp() external {
        deployer = new DeployRBT();
        (rbt, vault) = deployer.run();
        handler = new Handler(rbt, vault);

        targetContract(address(handler));
    }

    function invariant_mintedShouldEqualDepositsIfTimeHeldConstant() public view {
        uint256 deposits = address(vault).balance;
        uint256 totalRbt = rbt.totalSupply();

        console.log("Total Deposits: ", deposits);
        console.log("Total Rebase Tokens: ", totalRbt);
        console.log("Amount of additional rewards dealt: ", handler.additionalRewardsDealt());

        console.log("Times Deposit Called Successfully: : ", handler.timesDepositCalled());
        console.log("Times Redeem Called Successfully: : ", handler.timesRedeemCalled());
        console.log("Times Transfer Called Successfully: : ", handler.timesTransferCalled());
        console.log("Times TransferFrom Called Successfully: : ", handler.timesTransferFromCalled());

        // allow 1 wei margin of error to account for precision loss due to truncation of amounts less than 1 wei
        assertApproxEqAbs(deposits, totalRbt, 1);
    }

    function invariant_gettersShouldNeverRevert() public view {
        // rebase token getters
        rbt.getGlobalInterestRate();
        rbt.getUserInterestRate(msg.sender);
        rbt.getUserUpdatedAt(msg.sender);
        rbt.principalBalanceOf(msg.sender);
        rbt.balanceOf(msg.sender);
        // vault getters
        vault.getRebaseTokenAddress();
    }
}

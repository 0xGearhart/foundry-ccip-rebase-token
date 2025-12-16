// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants, DeployRBT} from "../../script/DeployRBT.s.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {InvalidReceiverMock} from "../mocks/InvalidReceiverMock.sol";
import {Test, console} from "forge-std/Test.sol";

contract VaultTest is Test, CodeConstants {
    DeployRBT public deployer;
    RebaseToken public rbt;
    Vault public vault;
    InvalidReceiverMock public invalidReceiver;

    uint256 public constant STARTING_USER_BALANCE = 20 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;
    uint256 public constant REDEEM_AMOUNT = 5 ether;
    uint256 public constant MAX_UINT_256 = type(uint256).max;
    uint256 public constant ONE_DAY = 1 days;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() external {
        deployer = new DeployRBT();
        (vault, rbt,,) = deployer.run(true);
        vm.deal(user1, STARTING_USER_BALANCE);
        vm.deal(user2, STARTING_USER_BALANCE);
        vm.deal(user3, STARTING_USER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDepositMintsRebaseTokens() external {
        uint256 startingEthBalance = user1.balance;
        uint256 startingContractBalance = address(vault).balance;
        assertEq(rbt.balanceOf(user1), 0);
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        assertEq(rbt.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(user1.balance, startingEthBalance - DEPOSIT_AMOUNT);
        assertEq(address(vault).balance, startingContractBalance + DEPOSIT_AMOUNT);
    }

    function testDepositEmitsEvents() external {
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, DEPOSIT_AMOUNT);
        vm.expectEmit(true, false, false, false, address(vault));
        emit Deposit(user1, DEPOSIT_AMOUNT);
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
    }

    /*//////////////////////////////////////////////////////////////
                                 REDEEM
    //////////////////////////////////////////////////////////////*/

    function testRedeemRevertsWhenRedeemSendFails() external {
        invalidReceiver = new InvalidReceiverMock();
        vm.deal(address(invalidReceiver), DEPOSIT_AMOUNT);
        vm.prank(address(invalidReceiver));
        vault.deposit{value: DEPOSIT_AMOUNT}();
        assertEq(rbt.balanceOf(address(invalidReceiver)), DEPOSIT_AMOUNT);
        assertEq(address(vault).balance, DEPOSIT_AMOUNT);

        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vm.prank(address(invalidReceiver));
        vault.redeem(DEPOSIT_AMOUNT);
        assertEq(rbt.balanceOf(address(invalidReceiver)), DEPOSIT_AMOUNT);
        assertEq(address(vault).balance, DEPOSIT_AMOUNT);
    }

    function testRedeemBurnsRebaseTokens() external {
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        // check balances before redeem
        uint256 startingEthBalance = user1.balance;
        uint256 startingContractBalance = address(vault).balance;
        assertEq(rbt.balanceOf(user1), DEPOSIT_AMOUNT);
        vm.prank(user1);
        vault.redeem(REDEEM_AMOUNT);
        // check balances after redeem and assert
        assertEq(rbt.balanceOf(user1), DEPOSIT_AMOUNT - REDEEM_AMOUNT);
        assertEq(user1.balance, startingEthBalance + REDEEM_AMOUNT);
        assertEq(address(vault).balance, startingContractBalance - REDEEM_AMOUNT);
    }

    function testRedeemBurnsFullTokenBalanceWhenUsingUint256MaxValue() external {
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        vm.warp(block.timestamp + ONE_DAY);
        // check balances before redeem
        uint256 startingEthBalance = user1.balance;
        uint256 startingContractBalance = address(vault).balance;
        uint256 startingRbtBalance = rbt.balanceOf(user1);
        uint256 expectedInterest = startingRbtBalance - rbt.principalBalanceOf(user1);
        vm.deal(address(vault), startingContractBalance + expectedInterest);
        assertEq(address(vault).balance, startingRbtBalance);
        // redeem type(uint256).max
        vm.prank(user1);
        vault.redeem(MAX_UINT_256);
        // check balances after redeem and assert
        assertEq(rbt.balanceOf(user1), 0);
        assertEq(user1.balance, startingEthBalance + startingRbtBalance);
        assertEq(address(vault).balance, 0);
    }

    function testRedeemEmitsEvents() external {
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(user1, address(0), REDEEM_AMOUNT);
        vm.expectEmit(true, false, false, false, address(vault));
        emit Redeem(user1, REDEEM_AMOUNT);
        vm.prank(user1);
        vault.redeem(REDEEM_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    function testReceiveHandlesEthAsExpected() external {
        uint256 startingEthBalance = user1.balance;
        uint256 startingContractBalance = address(vault).balance;
        vm.prank(user1);
        (bool success,) = address(vault).call{value: DEPOSIT_AMOUNT}("");
        assertEq(success, true);
        assertEq(user1.balance, startingEthBalance - DEPOSIT_AMOUNT);
        assertEq(address(vault).balance, startingContractBalance + DEPOSIT_AMOUNT);
        // assertEq(rbt.balanceOf(user1), DEPOSIT_AMOUNT);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants} from "../../script/DeployRBT.s.sol";
import {Ownable, RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Test, console} from "forge-std/Test.sol";

contract RebaseTokenFuzzTest is Test, CodeConstants {
    RebaseToken public rbt;
    Vault public vault;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    // use uint96 max to avoid overflow and math issues related to using uint256 max.
    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 constant MIN_DEPOSIT_SIZE = 1e5;
    uint256 constant ONE_DAY = 1 days;
    uint256 constant MAX_UINT_256 = type(uint256).max;
    uint256 constant MIN_TIME_INTERVAL = 1000;
    uint256 constant LOWER_INTEREST_RATE = 4e10;

    // uint256 public additionalRewardsDealt;

    function setUp() external {
        vm.startPrank(owner);
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
        vault = new Vault(rbt);
        rbt.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDepositInterestRateAccruesLinearlyWithFuzz(uint256 _amount) external {
        _amount = bound(_amount, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        vm.deal(user1, _amount);

        vm.prank(user1);
        vault.deposit{value: _amount}();

        uint256 startingBalance = rbt.balanceOf(user1);
        assertEq(startingBalance, _amount);
        vm.warp(block.timestamp + ONE_DAY);
        uint256 middleBalance = rbt.balanceOf(user1);
        uint256 firstDaysInterest = middleBalance - startingBalance;
        assertGt(middleBalance, startingBalance);
        vm.warp(block.timestamp + ONE_DAY);
        uint256 endingBalance = rbt.balanceOf(user1);
        uint256 secondDaysInterest = endingBalance - middleBalance;
        assertGt(endingBalance, middleBalance);

        // need to add 1 wei margin of error for truncation of tiny amounts less than 1 wei
        assertApproxEqAbs(firstDaysInterest, secondDaysInterest, 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 REDEEM
    //////////////////////////////////////////////////////////////*/

    function testDepositThenRedeemRightAwayWithFuzz(uint256 _amount) external {
        _amount = bound(_amount, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        vm.deal(user1, _amount);
        vm.prank(user1);
        vault.deposit{value: _amount}();
        assertEq(rbt.balanceOf(user1), _amount);
        uint256 vaultBalance = address(vault).balance;

        if (rbt.balanceOf(user1) > vaultBalance) {
            _addRewardsToVault(rbt.balanceOf(user1) - vaultBalance);
        }

        vm.prank(user1);
        vault.redeem(MAX_UINT_256);
        assertEq(rbt.balanceOf(user1), 0);
        assertEq(user1.balance, _amount);
    }

    function testDepositThenRedeemAfterSomeTimeWithFuzz(uint256 _amountToDeposit, uint256 _time) external {
        _time = bound(_time, MIN_TIME_INTERVAL, MAX_DEPOSIT_SIZE);
        _amountToDeposit = bound(_amountToDeposit, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        vm.deal(user1, _amountToDeposit);
        vm.prank(user1);
        vault.deposit{value: _amountToDeposit}();
        vm.warp(block.timestamp + _time);
        uint256 rbtBalanceAfterWarp = rbt.balanceOf(user1);
        if (rbtBalanceAfterWarp > address(vault).balance) {
            _addRewardsToVault(rbtBalanceAfterWarp - address(vault).balance);
        }
        vm.prank(user1);
        vault.redeem(MAX_UINT_256);

        uint256 ethBalanceAfterRedeem = user1.balance;
        assertEq(rbtBalanceAfterWarp, ethBalanceAfterRedeem);
        assertGt(ethBalanceAfterRedeem, _amountToDeposit);
    }

    /*//////////////////////////////////////////////////////////////
                                TRANSFER
    //////////////////////////////////////////////////////////////*/

    function testTransferWithFuzz(uint256 _amountToDeposit, uint256 _amountToSend) public {
        _amountToDeposit = bound(_amountToDeposit, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        _amountToSend = bound(_amountToSend, MIN_DEPOSIT_SIZE, _amountToDeposit);
        vm.deal(user1, _amountToDeposit);
        vm.prank(user1);
        vault.deposit{value: _amountToDeposit}();
        uint256 startingUser1Balance = rbt.balanceOf(user1);
        uint256 startingUser2Balance = rbt.balanceOf(user2);
        assertEq(startingUser1Balance, _amountToDeposit);
        assertEq(startingUser2Balance, 0);

        vm.prank(owner);
        rbt.setInterestRate(LOWER_INTEREST_RATE);

        vm.prank(user1);
        rbt.transfer(user2, _amountToSend);
        uint256 endingUser1Balance = rbt.balanceOf(user1);
        uint256 endingUser2Balance = rbt.balanceOf(user2);
        assert(rbt.getUserInterestRate(user1) != LOWER_INTEREST_RATE);
        assertEq(rbt.getUserInterestRate(user1), rbt.getUserInterestRate(user2));
        assertEq(startingUser1Balance - _amountToSend, endingUser1Balance);
        assertEq(startingUser2Balance + _amountToSend, endingUser2Balance);
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER FROM
    //////////////////////////////////////////////////////////////*/

    function testTransferFromWithFuzz(uint256 _amountToDeposit, uint256 _amountToSend) public {
        _amountToDeposit = bound(_amountToDeposit, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        _amountToSend = bound(_amountToSend, MIN_DEPOSIT_SIZE, _amountToDeposit);
        vm.deal(user1, _amountToDeposit);
        vm.prank(user1);
        vault.deposit{value: _amountToDeposit}();
        uint256 startingUser1Balance = rbt.balanceOf(user1);
        uint256 startingUser2Balance = rbt.balanceOf(user2);
        assertEq(startingUser1Balance, _amountToDeposit);
        assertEq(startingUser2Balance, 0);

        vm.prank(owner);
        rbt.setInterestRate(LOWER_INTEREST_RATE);

        vm.startPrank(user1);
        rbt.approve(user1, _amountToSend);
        rbt.transferFrom(user1, user2, _amountToSend);
        vm.stopPrank();
        uint256 endingUser1Balance = rbt.balanceOf(user1);
        uint256 endingUser2Balance = rbt.balanceOf(user2);
        assert(rbt.getUserInterestRate(user1) != LOWER_INTEREST_RATE);
        assertEq(rbt.getUserInterestRate(user1), rbt.getUserInterestRate(user2));
        assertEq(startingUser1Balance - _amountToSend, endingUser1Balance);
        assertEq(startingUser2Balance + _amountToSend, endingUser2Balance);
    }

    /*//////////////////////////////////////////////////////////////
                             MINT AND BURN
    //////////////////////////////////////////////////////////////*/

    function testMintRevertsWithoutRoleWithFuzz(uint256 _amountToMInt) public {
        uint256 userInterestRate = rbt.getUserInterestRate(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, MINT_AND_BURN_ROLE)
        );
        vm.prank(user1);
        rbt.mint(user1, _amountToMInt, userInterestRate);
    }

    function testBurnRevertsWithoutRoleWithFuzz(uint256 _amountToBurn) public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, MINT_AND_BURN_ROLE)
        );
        vm.prank(user1);
        rbt.burn(user1, _amountToBurn);
    }

    /*//////////////////////////////////////////////////////////////
                           SET INTEREST RATE
    //////////////////////////////////////////////////////////////*/

    function testSetInterestRevertsIfNotOwnerWithFuzz(uint256 _newInterestRate) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vm.prank(user1);
        rbt.setInterestRate(_newInterestRate);
    }

    /*//////////////////////////////////////////////////////////////
                        GRANT MINT AND BURN ROLE
    //////////////////////////////////////////////////////////////*/

    function testGrantRoleRevertsIfNotOwnerWithFuzz(address _addressToGrantRoleTo) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vm.prank(user1);
        rbt.grantMintAndBurnRole(_addressToGrantRoleTo);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _addRewardsToVault(uint256 _amount) private {
        uint256 vaultBalance = address(vault).balance;
        vm.deal(address(vault), vaultBalance + _amount);
        // additionalRewardsDealt += _amount;
    }
}

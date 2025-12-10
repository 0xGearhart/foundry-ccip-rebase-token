// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants} from "../../script/DeployRBT.s.sol";
import {Ownable, RebaseToken} from "../../src/RebaseToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Test, console} from "forge-std/Test.sol";

contract RebaseTokenTest is Test, CodeConstants {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    uint256 private constant PRECISION = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    RebaseToken public rbt;
    uint256 constant HIGHER_INTEREST_RATE = 9e10;
    uint256 constant LOWER_INTEREST_RATE = 4e10;
    uint256 constant MINT_AMOUNT = 100e18;
    uint256 constant BURN_AMOUNT = 25e18;
    uint256 constant TRANSFER_AMOUNT = 50e18;
    uint256 constant ONE_DAY = 1 days;

    event GlobalInterestRateChanged(uint256 oldInterestRate, uint256 newInterestRate);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event Transfer(address indexed from, address indexed to, uint256 value);

    modifier userMinted() {
        rbt.grantMintAndBurnRole(address(this));
        rbt.mint(user1, MINT_AMOUNT, rbt.getUserInterestRate(user1));
        rbt.mint(user2, MINT_AMOUNT, rbt.getUserInterestRate(user2));
        _;
    }

    modifier grantRole() {
        rbt.grantMintAndBurnRole(user1);
        _;
    }

    modifier advanceTime() {
        vm.warp(block.timestamp + ONE_DAY);
        _;
    }

    modifier lowerGlobalInterestRate() {
        rbt.setInterestRate(LOWER_INTEREST_RATE);
        _;
    }

    function setUp() external {
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
    }

    /*//////////////////////////////////////////////////////////////
                                  MINT
    //////////////////////////////////////////////////////////////*/

    function testMintRevertsWithoutRole() external {
        uint256 userInterestRate = rbt.getUserInterestRate(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, MINT_AND_BURN_ROLE)
        );
        vm.prank(user1);
        rbt.mint(user1, MINT_AMOUNT, userInterestRate);
    }

    function testMintAccruesInterestLinearly() external userMinted {
        uint256 initialTotal = rbt.balanceOf(user1);

        vm.warp(block.timestamp + ONE_DAY);
        uint256 middleTotal = rbt.balanceOf(user1);
        uint256 firstDaysInterest = middleTotal - initialTotal;

        vm.warp(block.timestamp + ONE_DAY);
        uint256 endingTotal = rbt.balanceOf(user1);
        uint256 secondDaysInterest = endingTotal - middleTotal;

        assertEq(firstDaysInterest, secondDaysInterest);
    }

    function testMintUpdatesState() external grantRole {
        (
            uint256 startingUserInterestRate,
            uint256 startingUserTimeStamp,
            uint256 startingPrincipalBalance,
            uint256 startingTotalBalance
        ) = _getAllInfoForUser(user1);
        assertEq(startingTotalBalance, 0);
        assertEq(startingPrincipalBalance, 0);
        assertEq(startingUserInterestRate, 0);
        assertEq(startingUserTimeStamp, 0);
        uint256 expectedTimestamp = block.timestamp;
        vm.prank(user1);
        rbt.mint(user1, MINT_AMOUNT, startingUserInterestRate);
        (
            uint256 endingUserInterestRate,
            uint256 endingUserTimeStamp,
            uint256 endingPrincipalBalance,
            uint256 endingTotalBalance
        ) = _getAllInfoForUser(user1);
        vm.warp(block.timestamp + 1);
        assertEq(endingUserInterestRate, INITIAL_INTEREST_RATE);
        assertEq(endingUserTimeStamp, expectedTimestamp);
        assertEq(startingPrincipalBalance + MINT_AMOUNT, endingPrincipalBalance);
        assertEq(endingPrincipalBalance, endingTotalBalance);
    }

    function testMintIncludesAccruedInterestOnSecondMintAndEmitsEvents() external userMinted grantRole advanceTime {
        (uint256 startingUserInterestRate,, uint256 startingPrincipalBalance, uint256 startingTotalBalance) =
            _getAllInfoForUser(user1);
        uint256 expectedInterest = startingTotalBalance - startingPrincipalBalance;
        uint256 calculatedTotalWithInterest =
            (startingPrincipalBalance * (PRECISION + (startingUserInterestRate * ONE_DAY))) / PRECISION;
        assertEq(startingTotalBalance, calculatedTotalWithInterest);
        assertEq(expectedInterest, calculatedTotalWithInterest - startingPrincipalBalance);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, expectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, MINT_AMOUNT);
        vm.prank(user1);
        rbt.mint(user1, MINT_AMOUNT, rbt.getUserInterestRate(user1));
        (,, uint256 endingPrincipalBalance, uint256 endingTotalBalance) = _getAllInfoForUser(user1);
        assertEq(startingPrincipalBalance + expectedInterest + MINT_AMOUNT, endingPrincipalBalance);
        assertEq(endingPrincipalBalance, endingTotalBalance);
    }

    /*//////////////////////////////////////////////////////////////
                                  BURN
    //////////////////////////////////////////////////////////////*/

    function testBurnRevertsWithoutRole() external userMinted {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, MINT_AND_BURN_ROLE)
        );
        vm.prank(user1);
        rbt.burn(user1, BURN_AMOUNT);
    }

    function testBurnUpdatesStateAndTimestamp() external userMinted grantRole lowerGlobalInterestRate {
        (
            uint256 startingUserInterestRate,
            uint256 startingUserTimeStamp,
            uint256 startingPrincipalBalance,
            uint256 startingTotalBalance
        ) = _getAllInfoForUser(user1);
        assertEq(startingTotalBalance, MINT_AMOUNT);
        assertEq(startingPrincipalBalance, MINT_AMOUNT);
        assertEq(startingUserInterestRate, INITIAL_INTEREST_RATE);
        assert(startingUserTimeStamp != 0);
        vm.warp(block.timestamp + 1);
        uint256 expectedInterest = rbt.balanceOf(user1) - startingPrincipalBalance;
        vm.prank(user1);
        rbt.burn(user1, BURN_AMOUNT);
        (
            uint256 endingUserInterestRate,
            uint256 endingUserTimeStamp,
            uint256 endingPrincipalBalance,
            uint256 endingTotalBalance
        ) = _getAllInfoForUser(user1);
        // should stay as initial interest rate as personal interest rates are not changed during burn so lowering global interest before burn should have no effect
        assertEq(endingUserInterestRate, INITIAL_INTEREST_RATE);
        assert(endingUserTimeStamp > startingUserTimeStamp);
        assertEq(startingTotalBalance + expectedInterest - BURN_AMOUNT, endingTotalBalance);
        assertEq(endingPrincipalBalance, endingTotalBalance);
    }

    function testBurnFullBalanceAndEmitsEvents() external userMinted grantRole advanceTime {
        (uint256 startingUserInterestRate,, uint256 startingPrincipalBalance, uint256 startingTotalBalance) =
            _getAllInfoForUser(user1);
        vm.warp(block.timestamp + 1);
        uint256 expectedInterest = rbt.balanceOf(user1) - startingPrincipalBalance;
        uint256 amountToBurn = rbt.balanceOf(user1);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, expectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(user1, address(0), startingTotalBalance + expectedInterest);
        vm.prank(user1);
        rbt.burn(user1, amountToBurn);
        (
            uint256 endingUserInterestRate,
            uint256 endingUserTimeStamp,
            uint256 endingPrincipalBalance,
            uint256 endingTotalBalance
        ) = _getAllInfoForUser(user1);
        assertEq(endingUserInterestRate, startingUserInterestRate);
        assertEq(endingPrincipalBalance, 0);
        assertEq(endingTotalBalance, 0);
        assertEq(endingUserTimeStamp, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                                TRANSFER
    //////////////////////////////////////////////////////////////*/

    function testTransferUpdatesReceiversInterestRateIfTheyHaveNoBalance() external userMinted {
        (
            uint256 user3StartingUserInterestRate,
            uint256 user3StartingUserTimeStamp,,
            uint256 user3StartingTotalBalance
        ) = _getAllInfoForUser(user3);
        assertEq(user3StartingTotalBalance, 0);
        assertEq(user3StartingUserInterestRate, 0);
        assertEq(user3StartingUserTimeStamp, 0);
        uint256 expectedTimestamp = block.timestamp;
        vm.prank(user1);
        rbt.transfer(user3, TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user3), user3StartingTotalBalance + TRANSFER_AMOUNT);
        assertEq(rbt.getUserInterestRate(user1), rbt.getUserInterestRate(user3));
        assertEq(rbt.getUserUpdatedAt(user3), expectedTimestamp);
    }

    function testTransferUpdatesState() external userMinted {
        vm.warp(block.timestamp + 1);
        (uint256 startingUserInterestRate,,, uint256 startingTotalBalance) = _getAllInfoForUser(user1);
        (uint256 user2StartingUserInterestRate,,, uint256 user2StartingTotalBalance) = _getAllInfoForUser(user2);
        uint256 expectedTimestamp = block.timestamp;
        vm.prank(user1);
        rbt.transfer(user2, TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user1), startingTotalBalance - TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user2), user2StartingTotalBalance + TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user1), rbt.principalBalanceOf(user1));
        assertEq(rbt.balanceOf(user2), rbt.principalBalanceOf(user2));
        assertEq(rbt.getUserUpdatedAt(user1), expectedTimestamp);
        assertEq(rbt.getUserUpdatedAt(user2), expectedTimestamp);
        assertEq(rbt.getUserInterestRate(user1), startingUserInterestRate);
        assertEq(rbt.getUserInterestRate(user2), user2StartingUserInterestRate);
    }

    function testTransferFullBalanceWhenUsingMaxUint256AndEmitsEvents() external userMinted advanceTime {
        (uint256 startingUserInterestRate,, uint256 startingPrincipalBalance, uint256 startingTotalBalance) =
            _getAllInfoForUser(user1);
        uint256 user1ExpectedInterest = startingTotalBalance - startingPrincipalBalance;
        uint256 user2StartingTotalBalance = rbt.balanceOf(user2);
        uint256 user2StartingInterestRate = rbt.getUserInterestRate(user2);
        uint256 user2ExpectedInterest = user2StartingTotalBalance - rbt.principalBalanceOf(user2);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, user1ExpectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user2, user2ExpectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(user1, user2, startingTotalBalance);
        vm.prank(user1);
        rbt.transfer(user2, type(uint256).max);
        assertEq(rbt.balanceOf(user1), 0);
        assertEq(rbt.balanceOf(user2), user2StartingTotalBalance + startingTotalBalance);
        assertEq(rbt.getUserInterestRate(user1), startingUserInterestRate);
        assertEq(rbt.getUserInterestRate(user2), user2StartingInterestRate);
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER FROM
    //////////////////////////////////////////////////////////////*/

    function testTransferFromUpdatesReceiversInterestRateIfTheyHaveNoBalance() external userMinted {
        vm.prank(user1);
        rbt.approve(user1, TRANSFER_AMOUNT);
        (
            uint256 user3StartingUserInterestRate,
            uint256 user3StartingUserTimeStamp,,
            uint256 user3StartingTotalBalance
        ) = _getAllInfoForUser(user3);
        assertEq(user3StartingTotalBalance, 0);
        assertEq(user3StartingUserInterestRate, 0);
        assertEq(user3StartingUserTimeStamp, 0);
        uint256 expectedTimestamp = block.timestamp;
        vm.prank(user1);
        rbt.transferFrom(user1, user3, TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user3), user3StartingTotalBalance + TRANSFER_AMOUNT);
        assertEq(rbt.getUserInterestRate(user1), rbt.getUserInterestRate(user3));
        assertEq(rbt.getUserUpdatedAt(user3), expectedTimestamp);
    }

    function testTransferFromUpdatesState() external userMinted {
        vm.prank(user1);
        rbt.approve(user1, TRANSFER_AMOUNT);
        vm.warp(block.timestamp + 1);
        (uint256 startingUserInterestRate,,, uint256 startingTotalBalance) = _getAllInfoForUser(user1);
        (uint256 user2StartingUserInterestRate,,, uint256 user2StartingTotalBalance) = _getAllInfoForUser(user2);
        uint256 expectedTimestamp = block.timestamp;
        vm.prank(user1);
        rbt.transferFrom(user1, user2, TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user1), startingTotalBalance - TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user2), user2StartingTotalBalance + TRANSFER_AMOUNT);
        assertEq(rbt.balanceOf(user1), rbt.principalBalanceOf(user1));
        assertEq(rbt.balanceOf(user2), rbt.principalBalanceOf(user2));
        assertEq(rbt.getUserUpdatedAt(user1), expectedTimestamp);
        assertEq(rbt.getUserUpdatedAt(user2), expectedTimestamp);
        assertEq(rbt.getUserInterestRate(user1), startingUserInterestRate);
        assertEq(rbt.getUserInterestRate(user2), user2StartingUserInterestRate);
    }

    function testTransferFromFullBalanceWhenUsingMaxUint256AndEmitsEvents() external userMinted advanceTime {
        (uint256 startingUserInterestRate,, uint256 startingPrincipalBalance, uint256 startingTotalBalance) =
            _getAllInfoForUser(user1);
        uint256 user1ExpectedInterest = startingTotalBalance - startingPrincipalBalance;
        uint256 user2StartingTotalBalance = rbt.balanceOf(user2);
        uint256 user2StartingInterestRate = rbt.getUserInterestRate(user2);
        uint256 user2ExpectedInterest = user2StartingTotalBalance - rbt.principalBalanceOf(user2);
        vm.prank(user1);
        rbt.approve(user1, startingTotalBalance);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user1, user1ExpectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(address(0), user2, user2ExpectedInterest);
        vm.expectEmit(true, true, false, false, address(rbt));
        emit Transfer(user1, user2, startingTotalBalance);
        vm.prank(user1);
        rbt.transferFrom(user1, user2, type(uint256).max);
        assertEq(rbt.balanceOf(user1), 0);
        assertEq(rbt.balanceOf(user2), user2StartingTotalBalance + startingTotalBalance);
        assertEq(rbt.getUserInterestRate(user1), startingUserInterestRate);
        assertEq(rbt.getUserInterestRate(user2), user2StartingInterestRate);
    }

    /*//////////////////////////////////////////////////////////////
                        GRANT MINT AND BURN ROLE
    //////////////////////////////////////////////////////////////*/

    function testGrantMintAndBurnRoleRevertsWhenNotCalledByOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vm.prank(user1);
        rbt.grantMintAndBurnRole(user2);
    }

    function testGrantMintAndBurnRoleEmitsEvents() external {
        vm.expectEmit(true, true, true, false, address(rbt));
        emit RoleGranted(MINT_AND_BURN_ROLE, user1, address(this));
        rbt.grantMintAndBurnRole(user1);
    }

    /*//////////////////////////////////////////////////////////////
                           SET INTEREST RATE
    //////////////////////////////////////////////////////////////*/

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

    function testSetInterestRateUpdatesState() external {
        rbt.setInterestRate(LOWER_INTEREST_RATE);
        assertEq(rbt.getGlobalInterestRate(), LOWER_INTEREST_RATE);
    }

    function testSetInterestRateEmitsEvent() external {
        vm.expectEmit(false, false, false, false, address(rbt));
        emit GlobalInterestRateChanged(INITIAL_INTEREST_RATE, LOWER_INTEREST_RATE);
        rbt.setInterestRate(LOWER_INTEREST_RATE);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testGetUserInterestRate() external view {
        assertEq(rbt.getUserInterestRate(user1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAllInfoForUser(address _user)
        internal
        view
        returns (uint256 userInterestRate, uint256 lastUpdated, uint256 principalBalance, uint256 totalBalance)
    {
        userInterestRate = rbt.getUserInterestRate(_user);
        lastUpdated = rbt.getUserUpdatedAt(_user);
        principalBalance = rbt.principalBalanceOf(_user);
        totalBalance = rbt.balanceOf(_user);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../../../src/RebaseToken.sol";
import {Vault} from "../../../src/Vault.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test, console} from "forge-std/Test.sol";

contract Handler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    RebaseToken public rbt;
    Vault public vault;

    uint256 public timesDepositCalled;
    uint256 public timesRedeemCalled;
    uint256 public timesTransferCalled;
    uint256 public timesTransferFromCalled;
    uint256 public additionalRewardsDealt;

    EnumerableSet.AddressSet internal usersWithDeposits;

    // use uint96 max to avoid overflow and math issues related to using uint256 max.
    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public constant MIN_DEPOSIT_SIZE = 1e5;

    constructor(RebaseToken _rbt, Vault _vault) {
        rbt = _rbt;
        vault = _vault;
    }

    /*//////////////////////////////////////////////////////////////
                                 VAULT
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 _amount) public {
        if (uint160(msg.sender) < 0x100 || msg.sender.code.length != 0) {
            return;
        }
        _amount = bound(_amount, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        vm.deal(msg.sender, _amount);
        vm.prank(msg.sender);
        vault.deposit{value: _amount}();
        _checkIfAddressShouldBeAdded(msg.sender);
        timesDepositCalled++;
    }

    function redeem(uint256 _addressSeed, uint256 _amount) public {
        address sender = _getDepositedAddressFromSeed(_addressSeed);
        _amount = bound(_amount, 0, rbt.balanceOf(sender));
        if (_amount == 0 || sender == address(0)) {
            return;
        }
        uint256 vaultBalance = address(vault).balance;
        if (_amount > vaultBalance) {
            _addRewardsToVault(_amount - vaultBalance);
        }
        vm.startPrank(sender);
        rbt.approve(address(vault), _amount);
        vault.redeem(_amount);
        vm.stopPrank();

        _checkIfAddressShouldBeRemoved(sender);
        timesRedeemCalled++;
    }

    /*//////////////////////////////////////////////////////////////
                              REBASE TOKEN
    //////////////////////////////////////////////////////////////*/

    function transfer(uint256 _addressSeed, uint256 _amount) public {
        address sender = _getDepositedAddressFromSeed(_addressSeed);
        if (uint160(msg.sender) < 0x100 || msg.sender.code.length != 0) {
            return;
        }
        address receiver = msg.sender;
        _amount = bound(_amount, 0, rbt.balanceOf(sender));
        if (_amount == 0 || sender == address(0)) {
            return;
        }
        vm.prank(sender);
        rbt.transfer(receiver, _amount);

        _checkIfAddressShouldBeAdded(receiver);
        _checkIfAddressShouldBeRemoved(sender);
        timesTransferCalled++;
    }

    function transferFrom(uint256 _addressSeed, uint256 _amount) public {
        address sender = _getDepositedAddressFromSeed(_addressSeed);
        if (uint160(msg.sender) < 0x100 || msg.sender.code.length != 0) {
            return;
        }

        address receiver = msg.sender;
        _amount = bound(_amount, 0, rbt.balanceOf(sender));
        if (_amount == 0 || sender == address(0)) {
            return;
        }
        vm.startPrank(sender);
        rbt.approve(sender, _amount);
        rbt.transferFrom(sender, receiver, _amount);
        vm.stopPrank();

        _checkIfAddressShouldBeAdded(receiver);
        _checkIfAddressShouldBeRemoved(sender);
        timesTransferFromCalled++;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _getDepositedAddressFromSeed(uint256 _addressSeed) private view returns (address) {
        uint256 arrayLength = usersWithDeposits.length();
        // if length is zero, return invalid address so handler knows to exit before fail
        if (arrayLength == 0) {
            return address(0);
        }
        // modulo length to select random index within usersWithDeposits address array
        uint256 index = _addressSeed % arrayLength;
        return usersWithDeposits.at(index);
    }

    function _addRewardsToVault(uint256 _amount) private {
        uint256 vaultBalance = address(vault).balance;
        vm.deal(address(vault), vaultBalance + _amount);
        additionalRewardsDealt += _amount;
    }

    function _checkIfAddressShouldBeRemoved(address _address) private {
        if (rbt.balanceOf(_address) == 0 && usersWithDeposits.contains(_address)) {
            usersWithDeposits.remove(_address);
        }
        return;
    }

    function _checkIfAddressShouldBeAdded(address _address) private {
        if (!usersWithDeposits.contains(_address)) {
            usersWithDeposits.add(_address);
        }
        return;
    }
}

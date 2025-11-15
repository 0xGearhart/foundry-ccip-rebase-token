// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IRebaseToken private immutable i_rbt;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);

    event Redeem(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IRebaseToken _rebaseToken) {
        i_rbt = _rebaseToken;
    }

    /*//////////////////////////////////////////////////////////////
                       RECEIVE/FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL & PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit an amount of ETH to mint rebase tokens (RBT)
     */
    function deposit() external payable {
        i_rbt.mint(msg.sender, msg.value, i_rbt.getUserInterestRate(msg.sender));
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Burn rebase tokens (RBT) to withdraw deposited ETH
     * @param _amount Amount of rebase tokens to burn
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rbt.balanceOf(msg.sender);
        }
        i_rbt.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL & PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                         VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the address of the rebase token (RBT)
     * @return Rebase token (RBT) address
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rbt);
    }
}

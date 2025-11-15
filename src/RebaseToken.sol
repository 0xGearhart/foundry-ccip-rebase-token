// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Gearhart
 * @notice Cross chain rebase token meant to incentivize users to make early vault deposits.
 *
 * Each depositing user will have their own interest rate set as a snapshot of the global
 * interest rate at the time of deposit.
 *
 * Global and personal interest rates can only be decreased.
 *
 * @dev Utilizing Chainlink CCIP for cross-chain functionality.
 */
contract RebaseToken is ERC20, Ownable, AccessControl, IRebaseToken {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256 currentInterestRate, uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant PRECISION = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_globalInterestRate;
    mapping(address user => uint256 personalInterestRate) private s_userInterestRate;
    mapping(address user => uint256 lastUpdatedTimestamp) private s_userUpdatedAt;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event GlobalInterestRateChanged(uint256 oldInterestRate, uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialInterestRate
    )
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        s_globalInterestRate = _initialInterestRate;
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL & PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint RBT tokens to an address when depositing into the vault
     * @param _to Address to receive minted RBT tokens
     * @param _amount Amount of RBT tokens to mint
     * @dev Only callable from address with mint and burn permissions
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        if (_userInterestRate == 0) {
            _userInterestRate = s_globalInterestRate;
        }
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn an amount of RBT tokens when withdrawing from the vault
     * @param _from Address to burn tokens from
     * @param _amount Amount of RBT tokens to burn
     * @dev Only callable from address with mint and burn permissions
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Transfer tokens to another address
     * @param _to Address to transfer tokens to
     * @param _amount Amount of tokens to transfer
     * @return True if transfer was successful
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param _from Address to transfer tokens from
     * @param _to Address to transfer tokens to
     * @param _amount Amount of tokens to transfer
     * @return True if transfer was successful
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice Set the global interest rate for the protocol. Interest rate can only decrease
     * @param _newGlobalInterestRate The new interest rate
     * @dev Only callable by contract owner
     */
    function setInterestRate(uint256 _newGlobalInterestRate) external onlyOwner {
        // make sure new interest rate is lower than current interest rate
        if (_newGlobalInterestRate > s_globalInterestRate) {
            revert RebaseToken__InterestRateCanOnlyBeDecreased(s_globalInterestRate, _newGlobalInterestRate);
        }
        emit GlobalInterestRateChanged(s_globalInterestRate, _newGlobalInterestRate);
        s_globalInterestRate = _newGlobalInterestRate;
    }

    /**
     * @notice Grants minting and burning permission to an address
     * @param _account Address to receive mint and burn privileges
     * @dev Only callable by contract owner
     */
    function grantMintAndBurnRole(address _account) public onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL & PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Mint the accrued interest for a user before updating their personal interest rate
     */
    function _mintAccruedInterest(address _user) private {
        // (1) get their current balance of minted RBT -> principal
        uint256 principalBalance = super.balanceOf(_user);
        // (2) calculate current balance including any interest -> balanceOf
        uint256 totalBalance = balanceOf(_user);
        // calculate number of RBT tokens that need to be minted to the user -> (2)-(1) = interest
        uint256 interestToBeMinted = totalBalance - principalBalance;
        // set last updated timestamp for user
        s_userUpdatedAt[_user] = block.timestamp;
        // mint interest to user
        _mint(_user, interestToBeMinted);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Calculate the amount of interest accrued for a user since last update timestamp.
     * Calculation is based on their personal interest rate.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // calculate interest that has accrued since last user update
        uint256 timeElapsed = block.timestamp - s_userUpdatedAt[_user];
        linearInterest = PRECISION + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Get the current global interest rate for the protocol
     * @return The current global interest rate
     */
    function getGlobalInterestRate() external view returns (uint256) {
        return s_globalInterestRate;
    }

    /**
     * @notice Get current interest rate for a specific user
     * @param _user Address of the user to get interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Get timestamp when user last updated interest rate
     * @param _user Address of the user to get timestamp for
     * @return Timestamp of last update
     */
    function getUserUpdatedAt(address _user) external view returns (uint256) {
        return s_userUpdatedAt[_user];
    }

    /**
     * @notice Gets total balance of a user, including rebase interest earned
     * @param _user Address of user to get balance of
     * @return Principal balance plus un-minted interest
     * @dev Override ERC20 balanceOf to reflect interest earned through rebase mechanic
     */
    function balanceOf(address _user) public view override(IRebaseToken, ERC20) returns (uint256) {
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION;
    }

    /**
     * @notice Get the principal balance of a user. This is the current minted RBT balance of the user without calculating the interest accrued since last user update timestamp
     * @param _user Address of user to get the principal balance of
     * @return Current principal RBT balance before adding interest
     * @dev Calls original ERC20 balanceOf function
     */
    function principalBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }
}

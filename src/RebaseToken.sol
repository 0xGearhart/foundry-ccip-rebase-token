// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

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
contract RebaseToken is ERC20, Ownable {
    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256 currentInterestRate, uint256 newInterestRate);

    uint256 private s_globalInterestRate;

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

    function setInterestRate(uint256 _newGlobalInterestRate) external onlyOwner {
        if (_newGlobalInterestRate > s_globalInterestRate) {
            revert RebaseToken__InterestRateCanOnlyBeDecreased(s_globalInterestRate, _newGlobalInterestRate);
        }
        s_globalInterestRate = _newGlobalInterestRate;
    }

    function getGlobalInterestRate() external view returns (uint256) {
        return s_globalInterestRate;
    }
}

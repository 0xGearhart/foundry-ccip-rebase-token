// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title IRebaseToken
 * @author Gearhart
 * @notice Interface for rebase token (RBT) contract
 */
interface IRebaseToken {
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external;
    function burn(address _from, uint256 _amount) external;
    function balanceOf(address _user) external view returns (uint256);
    function principalBalanceOf(address _user) external view returns (uint256);
    function getUserInterestRate(address _user) external view returns (uint256);
    function getUserUpdatedAt(address _user) external view returns (uint256);
    function getGlobalInterestRate() external view returns (uint256);
}

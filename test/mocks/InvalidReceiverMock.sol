// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// mock contract to simulate a depositing address without a fallback that cannot receive ETH when redeeming.
// this is used to test revert error message in vault contract that is unreachable otherwise.
contract InvalidReceiverMock {}

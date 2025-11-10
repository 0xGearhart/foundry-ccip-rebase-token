// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    // RBT name and symbol
    string public constant RBT_NAME = "Rebase Token";
    string public constant RBT_SYMBOL = "RBT";
    uint256 public constant INITIAL_INTEREST_RATE = 5e10;
    // mainnet chain id and info
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    // sepolia chain id and info
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    // local chain id and info
    uint256 public constant LOCAL_CHAIN_ID = 31_337;
}

contract HelperConfig is Script, CodeConstants {
    // struct NetworkConfig {}
    //  constructor() {
    //     if (block.chainid == ETH_MAINNET_CHAIN_ID) {
    //         activeNetworkConfig = getMainnetEthConfig();
    //     } else if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
    //         activeNetworkConfig = getSepoliaEthConfig();
    //     } else {
    //         activeNetworkConfig = getOrCreateAnvilEthConfig();
    //     }
    // }

    }

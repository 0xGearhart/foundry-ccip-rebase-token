// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";

import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    // RBT name
    string public constant RBT_NAME = "Rebase Token";
    // RBT symbol
    string public constant RBT_SYMBOL = "RBT";
    //RBT initial interest rate
    uint256 public constant INITIAL_INTEREST_RATE = 5e10;
    // RBT Token Pool Info
    uint8 public constant DECIMAL_PRECISION = 18;
    // mainnet chain id and info
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    // sepolia chain id and info
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    // local chain id and info
    uint256 public constant LOCAL_CHAIN_ID = 31_337;
}

contract DeployRBT is Script, CodeConstants {
    RebaseToken deployedRbt;
    address[] allowList; // blank address array for allowlist == anyone can use the bridge

    function run()
        external
        returns (RebaseToken rbt, RebaseTokenPool rbtPool, CCIPLocalSimulatorFork ccipLocalSimulatorFork)
    {
        vm.startBroadcast(_getAccount());
        // deploy RBT contract
        rbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
        vm.stopBroadcast();
        // save RBT to storage for vault deployment if needed
        deployedRbt = rbt;

        // only needed for fork tests and deployments, ignore for local anvil chain
        if (block.chainid != LOCAL_CHAIN_ID) {
            // deploy CCIP local simulation contracts to get chain specific network details
            ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
            Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
            vm.startBroadcast(vm.envAddress("DEFAULT_KEY_ADDRESS"));
            // deploy RBT Pool contract
            rbtPool = new RebaseTokenPool(
                IERC20(address(rbt)),
                DECIMAL_PRECISION,
                allowList,
                networkDetails.rmnProxyAddress,
                networkDetails.routerAddress
            );
            // grant MINT_AND_BURN role to RBT Pool contract
            rbt.grantMintAndBurnRole(address(rbtPool));
            // grant appropriate chainlink CCIP admin, permissions, and roles
            RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
                .registerAdminViaOwner(address(rbt));
            TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rbt));
            TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(rbt), address(rbtPool));
            vm.stopBroadcast();
        }
    }

    function deployVault() external returns (Vault vault) {
        vm.startBroadcast(_getAccount());
        // deploy vault contract
        vault = new Vault(deployedRbt);
        // grant MINT_AND_BURN role to vault contract
        deployedRbt.grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }

    // get address to deploy contracts from
    function _getAccount() internal view returns (address) {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return DEFAULT_SENDER;
        } else {
            return vm.envAddress("DEFAULT_KEY_ADDRESS");
        }
    }
}

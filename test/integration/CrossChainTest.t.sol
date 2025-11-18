// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// scripts and deployment
import {DeployRBT} from "../../script/DeployRBT.s.sol";
import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";

// contracts to test
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool, TokenPool, RateLimiter} from "../../src/RebaseTokenPool.sol";
import {Vault} from "../../src/Vault.sol";

// CCIP local testing infrastructure
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IRouterClient} from "@chainlink/local/lib/chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {BurnMintERC677Helper} from "@chainlink/local/src/ccip/BurnMintERC677Helper.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";

contract CrossChainTest is Test, CodeConstants {
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    RebaseToken ethSepoliaRbt;
    RebaseToken arbSepoliaRbt;
    RebaseTokenPool ethSepoliaRbtPool;
    RebaseTokenPool arbSepoliaRbtPool;
    Vault vault;

    IRouterClient sourceRouter;
    BurnMintERC677Helper sourceCCIPBnMToken;
    BurnMintERC677Helper destinationCCIPBnMToken;
    IERC20 sourceLinkToken;
    uint64 destinationChainSelector;

    uint256 sourceFork;
    uint256 destinationFork;
    address[] allowList;
    address owner = makeAddr("owner");

    function setUp() public {
        // create desired chain forks
        string memory ETH_SEPOLIA_RPC_URL = vm.envString("ETH_SEPOLIA_RPC_URL");
        string memory ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");
        // ETH Sepolia Fork (source)
        sourceFork = vm.createSelectFork(ETH_SEPOLIA_RPC_URL);
        // ARB Sepolia Fork (destination)
        destinationFork = vm.createFork(ARB_SEPOLIA_RPC_URL);

        // deploy CCIP local simulation contracts and make their addresses the same (persistent) across chains
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // deploy contracts and configure CCIP on ETH Sepolia
        vm.startPrank(owner);
        // chainlink CCIP local testing set up for source chain
        Register.NetworkDetails memory sourceNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sourceCCIPBnMToken = BurnMintERC677Helper(sourceNetworkDetails.ccipBnMAddress);
        sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);
        // deploy RBT, RBT Pool and Vault contracts on source chain
        ethSepoliaRbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
        vault = new Vault(ethSepoliaRbt);
        ethSepoliaRbtPool = new RebaseTokenPool(
            IERC20(address(ethSepoliaRbt)),
            DECIMAL_PRECISION,
            allowList,
            sourceNetworkDetails.rmnProxyAddress,
            sourceNetworkDetails.routerAddress
        );
        // grand MINT_AND_BURN role to vault and pool
        ethSepoliaRbt.grantMintAndBurnRole(address(vault));
        ethSepoliaRbt.grantMintAndBurnRole(address(ethSepoliaRbtPool));
        // grant appropriate chainlink CCIP admin, permissions, and roles
        RegistryModuleOwnerCustom(sourceNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(ethSepoliaRbt));
        TokenAdminRegistry(sourceNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(ethSepoliaRbt));
        TokenAdminRegistry(sourceNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(ethSepoliaRbt), address(ethSepoliaRbtPool));
        vm.stopPrank();

        // switch to destination chain fork (arbitrum sepolia)
        vm.selectFork(destinationFork);
        // deploy contracts and configure CCIP on ARB sepolia
        vm.startPrank(owner);
        // chainlink CCIP local testing set up for destination chain
        Register.NetworkDetails memory destinationNetworkDetails =
            ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        destinationCCIPBnMToken = BurnMintERC677Helper(destinationNetworkDetails.ccipBnMAddress);
        destinationChainSelector = destinationNetworkDetails.chainSelector;
        // deploy RBT and RBT Pool contracts on destination chain
        arbSepoliaRbt = new RebaseToken(RBT_NAME, RBT_SYMBOL, INITIAL_INTEREST_RATE);
        arbSepoliaRbtPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaRbt)),
            DECIMAL_PRECISION,
            allowList,
            destinationNetworkDetails.rmnProxyAddress,
            destinationNetworkDetails.routerAddress
        );
        // grand MINT_AND_BURN role to pool
        arbSepoliaRbt.grantMintAndBurnRole(address(arbSepoliaRbtPool));
        // grant appropriate chainlink CCIP admin, permissions, and roles
        RegistryModuleOwnerCustom(destinationNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaRbt));
        TokenAdminRegistry(destinationNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaRbt));
        TokenAdminRegistry(destinationNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaRbt), address(arbSepoliaRbtPool));
        
        // configure both pools
        configureTokenPool(sourceFork, address(ethSepoliaRbtPool), destinationNetworkDetails.chainSelector, address(arbSepoliaRbtPool), address(arbSepoliaRbt));
        configureTokenPool(destinationFork, address(arbSepoliaRbtPool), sourceNetworkDetails.chainSelector, address(ethSepoliaRbtPool), address(ethSepoliaRbt));
        vm.stopPrank();
    }

    function configureTokenPool(uint256 _fork, address _localPool, uint64 _remoteChainSelector, address _remotePool, address _remoteTokenAddress) public {
        vm.selectFork(_fork);
        bytes[] memory _remotePoolAddresses = new bytes[](1);
        _remotePoolAddresses[0] = abi.encode(_remotePool)
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        // struct ChainUpdate {
        //     uint64 remoteChainSelector; // Remote chain selector
        //     bytes[] remotePoolAddresses; // Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; // Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        // }
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            remotePoolAddresses: _remotePoolAddresses,
            remoteTokenAddress: abi.encode(_remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        vm.prank(owner);
        TokenPool(_localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
    }
}

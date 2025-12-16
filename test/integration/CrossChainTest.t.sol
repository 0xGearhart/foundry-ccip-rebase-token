// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// scripts and deployment
import {CodeConstants, DeployRBT} from "../../script/DeployRBT.s.sol";
import {ConfigurePool} from "../../script/Interactions.s.sol";

// contracts to test
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool, TokenPool} from "../../src/RebaseTokenPool.sol";
import {Vault} from "../../src/Vault.sol";

// CCIP local testing infrastructure
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";

contract CrossChainTest is Test, CodeConstants {
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    RebaseToken ethSepoliaRbt;
    RebaseToken arbSepoliaRbt;
    RebaseTokenPool ethSepoliaRbtPool;
    RebaseTokenPool arbSepoliaRbtPool;
    DeployRBT deployer;
    Vault vault;

    Register.NetworkDetails sourceNetworkDetails;
    Register.NetworkDetails destinationNetworkDetails;

    uint256 sourceFork;
    uint256 destinationFork;

    address owner = vm.envAddress("DEFAULT_KEY_ADDRESS");
    address user1 = makeAddr("user1");
    uint256 constant SEND_AMOUNT = 1e5;

    function setUp() public {
        // create desired chain forks
        string memory ETH_SEPOLIA_RPC_URL = vm.envString("ETH_SEPOLIA_RPC_URL");
        string memory ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");
        // ETH Sepolia Fork (source)
        sourceFork = vm.createSelectFork(ETH_SEPOLIA_RPC_URL);
        // ARB Sepolia Fork (destination)
        destinationFork = vm.createFork(ARB_SEPOLIA_RPC_URL);

        // deploy RBT, RBT Pool and Vault contracts on source chain
        deployer = new DeployRBT();
        (vault, ethSepoliaRbt, ethSepoliaRbtPool, ccipLocalSimulatorFork) = deployer.run(true);
        // deploy CCIP local simulation contracts and make their addresses the same (persistent) across chains
        vm.makePersistent(address(ccipLocalSimulatorFork));
        // get chainlink CCIP network details for source chain
        sourceNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        // switch to destination chain fork (arbitrum sepolia)
        vm.selectFork(destinationFork);
        // deploy RBT and RBT Pool contracts on ARB sepolia
        deployer = new DeployRBT();
        (, arbSepoliaRbt, arbSepoliaRbtPool,) = deployer.run(false);
        // get chainlink CCIP network details for destination chain
        destinationNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        // configure arb sepolia pool
        ConfigurePool configureDestinationPool = new ConfigurePool();
        configureDestinationPool.run(
            address(arbSepoliaRbtPool),
            sourceNetworkDetails.chainSelector,
            address(ethSepoliaRbtPool),
            address(ethSepoliaRbt),
            false,
            0,
            0,
            false,
            0,
            0
        );

        // switch back to eth sepolia chain
        vm.selectFork(sourceFork);
        // configure eth sepolia pool
        ConfigurePool configureSourcePool = new ConfigurePool();
        configureSourcePool.run(
            address(ethSepoliaRbtPool),
            destinationNetworkDetails.chainSelector,
            address(arbSepoliaRbtPool),
            address(arbSepoliaRbt),
            false,
            0,
            0,
            false,
            0,
            0
        );
    }

    function bridgeTokens(
        uint256 _amountToBridge,
        uint256 _localFork,
        uint256 _remoteFork,
        Register.NetworkDetails memory _localNetworkDetails,
        Register.NetworkDetails memory _remoteNetworkDetails,
        RebaseToken _localToken,
        RebaseToken _remoteToken
    )
        public
    {
        // select fork we are sending from (local)
        vm.selectFork(_localFork);
        // build tokenAmounts array of EVMTokenAmount structs
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(_localToken), amount: _amountToBridge});
        // build EVM2AnyMessage cross chain message struct
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user1), // bytes receiver: abi.encode(receiver address) for dest EVM chains.
            data: "", // bytes data: Data payload.
            tokenAmounts: tokenAmounts, // EVMTokenAmount[] tokenAmounts: Token transfers.
            feeToken: _localNetworkDetails.linkAddress, // address feeToken: Address of feeToken. address(0) means you will send msg.value.
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: 150_000, allowOutOfOrderExecution: false})
            ) // bytes extraArgs: Populate this with _argsToBytes(GenericExtraArgsV2).
        });
        // get dynamic transfer fee in link token. Fee amount dependant upon cross chain message being sent
        uint256 fee =
            IRouterClient(_localNetworkDetails.routerAddress).getFee(_remoteNetworkDetails.chainSelector, message);
        // mint link token for local tests
        ccipLocalSimulatorFork.requestLinkFromFaucet(user1, fee);
        // approve router to take fee in link token and send Rebase Tokens on behalf of user1
        vm.startPrank(user1);
        IERC20(_localNetworkDetails.linkAddress).approve(_localNetworkDetails.routerAddress, fee);
        IERC20(address(_localToken)).approve(_localNetworkDetails.routerAddress, _amountToBridge);
        // get balances for testing state locally
        uint256 localBalanceBeforeSend = _localToken.balanceOf(user1);
        uint256 localUserInterestRate = _localToken.getUserInterestRate(user1);
        // initiate cross chain transfer from local chain
        IRouterClient(_localNetworkDetails.routerAddress).ccipSend(_remoteNetworkDetails.chainSelector, message);
        vm.stopPrank();
        // test balances after send
        uint256 localBalanceAfterSend = _localToken.balanceOf(user1);
        assertEq(localBalanceAfterSend, localBalanceBeforeSend - _amountToBridge);

        // switch to remote chain
        vm.selectFork(_remoteFork);
        // advance time to simulate confirmation times for bridges
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBeforeSend = _remoteToken.balanceOf(user1);

        // switch back to localFork since ccipLocalSimulator assumes you are on source fork when calling switchChainAndRouteMessage
        vm.selectFork(_localFork);
        // finish cross chain transfer to remote chain
        ccipLocalSimulatorFork.switchChainAndRouteMessage(_remoteFork);
        // get and verify remote chain state after send
        uint256 expectedRemoteBalanceAfterSend = remoteBalanceBeforeSend + _amountToBridge;
        uint256 remoteUserInterestRate = _remoteToken.getUserInterestRate(user1);
        assertEq(_remoteToken.balanceOf(user1), expectedRemoteBalanceAfterSend);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sourceFork);
        vm.deal(user1, SEND_AMOUNT);
        vm.prank(user1);
        vault.deposit{value: SEND_AMOUNT}();
        assertEq(ethSepoliaRbt.balanceOf(user1), SEND_AMOUNT);
        bridgeTokens(
            SEND_AMOUNT,
            sourceFork,
            destinationFork,
            sourceNetworkDetails,
            destinationNetworkDetails,
            ethSepoliaRbt,
            arbSepoliaRbt
        );
    }

    function testBridgeAllTokensBack() public {
        vm.selectFork(sourceFork);
        vm.deal(user1, SEND_AMOUNT);
        vm.prank(user1);
        vault.deposit{value: SEND_AMOUNT}();
        assertEq(ethSepoliaRbt.balanceOf(user1), SEND_AMOUNT);
        bridgeTokens(
            SEND_AMOUNT,
            sourceFork,
            destinationFork,
            sourceNetworkDetails,
            destinationNetworkDetails,
            ethSepoliaRbt,
            arbSepoliaRbt
        );
        vm.selectFork(destinationFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            arbSepoliaRbt.balanceOf(user1),
            destinationFork,
            sourceFork,
            destinationNetworkDetails,
            sourceNetworkDetails,
            arbSepoliaRbt,
            ethSepoliaRbt
        );
    }

    // function testBridgeTokensTwiceFromSource() public {}

    // function testBridgeTokensTwiceFromDestination() public {}

    // function testBridgePartialTokens() public {}

    // function testBridgeTokensMintsAccruedInterestOnSource() public {}

    // function testBridgeTokensMintsAccruedInterestOnDestination() public {}
}

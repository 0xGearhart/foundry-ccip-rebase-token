// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Vault} from "../src/Vault.sol";
import {CodeConstants} from "./DeployRBT.s.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

contract ConfigurePool is Script, CodeConstants {
    bool outboundRateLimiterIsEnabled = false;
    uint128 outboundRateLimiterCapacity = 0;
    uint128 outboundRateLimiterRate = 0;
    bool inboundRateLimiterIsEnabled = false;
    uint128 inboundRateLimiterCapacity = 0;
    uint128 inboundRateLimiterRate = 0;

    function run(address _localPool, uint64 _remoteChainSelector, address _remotePool, address _remoteToken) public {
        // build array of remote pool addresses in byte format
        bytes[] memory remotePoolAddresses = new bytes[](1);
        // encode remote pool address for bytes array
        remotePoolAddresses[0] = abi.encode(_remotePool);
        // initialize array of ChainUpdateStructs
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        // build Chain Update struct
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(_remoteToken),
            // configure outbound rate limiter
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            // configure inbound rate limiter
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });
        // build array of chains to remove
        uint64[] memory chainsToRemove;

        vm.startBroadcast(vm.envAddress("DEFAULT_KEY_ADDRESS"));
        // configure pool
        TokenPool(_localPool).applyChainUpdates(chainsToRemove, chainsToAdd);
        vm.stopBroadcast();
    }
}

contract BridgeTokens is Script {
    function run(
        address _receiver,
        address _tokenToBridge,
        uint256 _amountToBridge,
        uint64 _destinationChainSelector,
        address _routerAddress,
        address _linkTokenAddress,
        uint256 _gasLimit // 0 should be fine on actual chain since it uses default gas but have to send large limit when testing on fork
    )
        public
    {
        // build token amounts array for ccip message
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _tokenToBridge, amount: _amountToBridge});
        // build extra args struct for ccip message
        bytes memory extraArgs =
            Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: _gasLimit, allowOutOfOrderExecution: false}));
        // build CCIP message
        vm.startBroadcast(vm.envAddress("DEFAULT_KEY_ADDRESS"));
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: _linkTokenAddress,
            extraArgs: extraArgs
        });
        // get dynamic transfer fee in link token. Fee amount dependant upon cross chain message being sent
        uint256 ccipFee = IRouterClient(_routerAddress).getFee(_destinationChainSelector, message);
        // approve link token to pay fee
        IERC20(_linkTokenAddress).approve(_routerAddress, ccipFee);
        // approve tokens to be bridged
        IERC20(_tokenToBridge).approve(_routerAddress, _amountToBridge);
        // bridge tokens
        IRouterClient(_routerAddress).ccipSend(_destinationChainSelector, message);
        vm.stopBroadcast();
    }
}

contract DepositAndMintRbt is Script {
    function run(address payable vault, uint256 amountToDeposit) public {
        vm.startBroadcast(vm.envAddress("DEFAULT_KEY_ADDRESS"));
        Vault(vault).deposit{value: amountToDeposit}();
        vm.stopBroadcast();
    }
}

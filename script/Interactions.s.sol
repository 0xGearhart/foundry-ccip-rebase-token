// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CodeConstants} from "./DeployRBT.s.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

contract ConfigurePool is Script, CodeConstants {
    function run(
        address _localPool,
        uint64 _remoteChainSelector,
        address _remotePool,
        address _remoteToken,
        bool _outboundRateLimiterIsEnabled,
        uint128 _outboundRateLimiterCapacity,
        uint128 _outboundRateLimiterRate,
        bool _inboundRateLimiterIsEnabled,
        uint128 _inboundRateLimiterCapacity,
        uint128 _inboundRateLimiterRate
    )
        public
    {
        // build array of remote pool addresses
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(_remotePool);
        // build array of chains to add
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(_remoteToken),
            // configure outbound rate limiter
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: _outboundRateLimiterIsEnabled,
                capacity: _outboundRateLimiterCapacity,
                rate: _outboundRateLimiterRate
            }),
            // configure inbound rate limiter
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: _inboundRateLimiterIsEnabled,
                capacity: _inboundRateLimiterCapacity,
                rate: _inboundRateLimiterRate
            })
        });
        // build array of chains to remove
        uint64[] memory chainsToRemove;

        vm.startBroadcast(_getAccount());
        TokenPool(_localPool).applyChainUpdates(chainsToRemove, chainsToAdd);
        vm.stopBroadcast();
    }

    function _getAccount() internal view returns (address) {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return DEFAULT_SENDER;
        } else {
            return vm.envAddress("DEFAULT_KEY_ADDRESS");
        }
    }
}

contract bridgeTokens is Script {
    function run(
        address _receiver,
        address _tokenToBridge,
        uint256 _amountToBridge,
        uint64 _destinationChainSelector,
        address _routerAddress,
        address _linkTokenAddress
    )
        public
    {
        // build token amounts array for ccip message
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _tokenToBridge, amount: _amountToBridge});
        // build extra args struct for ccip message
        bytes memory extraArgs =
            Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: false}));
        // build CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: _linkTokenAddress,
            extraArgs: extraArgs
        });
        // get dynamic transfer fee in link token. Fee amount dependant upon cross chain message being sent
        uint256 ccipFee = IRouterClient(_routerAddress).getFee(_destinationChainSelector, message);

        vm.startBroadcast();
        IERC20(_linkTokenAddress).approve(_routerAddress, ccipFee);
        IERC20(_tokenToBridge).approve(_routerAddress, _amountToBridge);
        IRouterClient(_routerAddress).ccipSend(_destinationChainSelector, message);
        vm.stopBroadcast();
    }
}

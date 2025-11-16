// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {IPoolV1, Pool, TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";

/**
 * @title RebaseTokenPool
 * @author Gearhart
 * @notice Cross chain token pool for rebase token.
 * @dev Utilizing Chainlink CCIP for cross-chain functionality.
 */
contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        uint8 _localTokenDecimals,
        address[] memory _allowlist,
        address _rmnProxy,
        address _router
    )
        TokenPool(_token, _localTokenDecimals, _allowlist, _rmnProxy, _router)
    {}

    /**
     * @inheritdoc IPoolV1
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        // validate info
        _validateLockOrBurn(lockOrBurnIn);
        // use the originalSender address from the struct so we can get the relevant information before bridging(burn/mint)
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        // address(this) has to be sent as the address that is burning since ccip has the pool contract do the burning on the users behalf
        // burn tokens on source chain
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        // return LockOrBurnOutV1 struct
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @inheritdoc IPoolV1
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        // validate info
        _validateReleaseOrMint(releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount);
        // decode bridge message info for setting user interest rate
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        // mint tokens on destination chain
        IRebaseToken(address(i_token))
            .mint(releaseOrMintIn.receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate);
        // return ReleaseOrMintOutV1 struct
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.sourceDenominatedAmount});
    }
}

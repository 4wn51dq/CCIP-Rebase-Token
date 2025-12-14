//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol"; // ccip@v2.9.0
import {Pool} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRT.sol";


contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowList, address _rmnProxy, address _router) 
        TokenPool(_token, _allowList, _rmnProxy, _router) {

    }

    // tokenPool contract is abstract, we need to implement the two functions from IPoolV1
    //  /// @notice Validates the lock or burn input for correctness on
      /// - token to be locked or burned
      /// - RMN curse status
      /// - allowlist status
      /// - if the sender is a valid onRamp
      /// - rate limit status
      /// @param lockOrBurnIn The input to validate.
      /// @dev This function should always be called before executing a lock or burn. Not doing so would allow
      /// for various exploits.

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn ) external 
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) 
    {
        _validateLockOrBurn(lockOrBurnIn); 
        address receiver = abi.decode(lockOrBurnIn.receiver, (address));
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(receiver);
        IRebaseToken(address(i_token)).burnRT(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external 
        returns (Pool.ReleaseOrMintOutV1 memory) 
    { 
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mintRT(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }

}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol"; 
import {RateLimiter} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";


contract ConfigurePool is Script {
    function run(address localPool,
    uint64 remoteChainSelector, 
    bytes memory remotePool, 
    address remoteToken, 
    bool outboundRateLimiterIsEnabled,
    uint128 outboundRateLimiterCapacity,
    uint128 outboundRateLimiterRate,
    bool inboundRateLimiterIsEnabled,
    uint128 inboundRateLimiterCapacity,
    uint128 inboundRateLimiterRate
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](0);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePool,
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled, 
                capacity: outboundRateLimiterCapacity, 
                rate: outboundRateLimiterRate 
                }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled, 
                capacity: inboundRateLimiterCapacity, 
                rate: inboundRateLimiterRate
                })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}
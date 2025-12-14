//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*  @notice we need a local CCIP environment that behaves like real CCIP infra, across forked blockchains.
    CCIPLocalSimulatorFork is a test-only helper contract that:
	•	Simulates Chainlink CCIP message passing
	•	Works across multiple forks
	•	Lets you test cross-chain logic without live CCIP
	•	And foundry forks do not talk to each other, this contract fills that gap.

*/

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "../lib/ccip//src/v0.8/ccip/tokenAdminRegistry/RegistryModuleCustomOwner.sol";
import {TokenAdminRegistry} from "../lib/ccip//src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol"; 
import {RateLimiter} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRT.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract CrossChainTest is Test {

    address private owner = makeAddr("OWNER");


    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepToken;
    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepNeworkDetails;

    CCIPLocalSimulatorFork localSimulatorFork;

    function configureTokenPool(
        uint256 fork, address localPool, uint64 remoteChainSelector, address remotePool, address remoteTokenAddress
        ) public {
            vm.selectFork(fork);
            vm.prank(owner);
            bytes[] memory remotePoolAddresses = new bytes[](1);
            remotePoolAddresses[0] = abi.encode(remotePool);
            TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
            chainsToAdd[0] = TokenPool.ChainUpdate({
                remoteChainSelector: remoteChainSelector,
                remotePoolAddresses: remotePoolAddresses,
                remoteTokenAddress: abi.encode(remoteTokenAddress),
                outboundRateLimiter: RateLimiter.Config({
                    isEnabled: false,
                    capacity: 0,
                    rate: 0
                }),
                inboundRateLimiter: RateLimiter.Config({
                    isEnabled: false,
                    capacity: 0,
                    rate: 0
                })
            });
        
    }

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia"); // create forkid for forked sepolia and we are running on it now
        arbSepoliaFork = vm.createFork("arb-sepolia"); // lly for forked arbitrum sepolia but do not select to run on it 
        // **now we have two parallel forked chains in memory.

        localSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(localSimulatorFork)); // the localsimulator contract is persistent across the two chains
        // ** it is the only contract allowed to live between the chains (or in both chains).

        // deploy and configure on sepolia (already selected)
        vm.prank(owner);

        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(sepoliaToken), 
            new address[](0), 
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress 
        );
        sepoliaToken.grantMintAndBurnRoles(address(vault));
        sepoliaToken.grantMintAndBurnRoles(address(sepoliaPool));

        RegistryModuleCustomOwner(sepoliaNetworkDetails.tokenAdminRegistryAddress).registerAdminViaOwner(
            address(sepoliaToken)
        ); // register EOA as token admin to enable token in CCIP
        TokeAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(sepoliaToken)
        );
        TokeAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool();
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepNetworkDetails.chainSelector,
            address(arbSepPool),
            address(arbSepToken)
        );
        configureTokenPool(
            arbSepFork,
            address(arbSepPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
        vm.stopPrank();
        
        // deply and configure on arbsep
        vm.selectFork(arbSepoliaFork);
        vm.prank(owner);
        arbSepToken = new RebaseToken();
        arbSebPool = new RebaseTokenPool(
            IERC20(arbSepToken),
            new address[](0),
            arbSepNeworkDetails.rmnProxyAddress,
            arbSepNeworkDetails.routerAddress
        );
        arbSepToken.grantMintAndBurnRoles(address(arbSepPool));
        TokeAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(arbSepToken)
        );
        vm.stopPrank();
    }
}

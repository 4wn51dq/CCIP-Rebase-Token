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
import {RegistryModuleOwnerCustom} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol"; 
import {RateLimiter} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRT.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract CrossChainTest is Test {

    address private owner = makeAddr("OWNER");
    address private user = makeAddr("USER");
    address private constant sepoliaRouterAddress = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    address private constant arbSepRouterAddress = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    address private constant sepoliaRmnProxy = 0x4e9935be37302B9C97Ff4ae6868F1b566ade26d2;
    address private constant arbSepRmnProxy = 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    uint256 private constant CUSTOM_GAS_LIMIT = 0;
    uint256 private constant SEND_VALUE = 1e5;

    RebaseToken sepoliaToken;
    RebaseToken arbSepToken;
    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepNetworkDetails;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryArbitrum;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomArbSepolia;

    CCIPLocalSimulatorFork localSimulatorFork;

    function bridgeTokens(
        uint256 amountToBridge, uint256 localFork, uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails, Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken, RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);

        Client.EVMTokenAmount[] memory _tokenAmounts = new Client.EVMTokenAmount[](1) ;
        _tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: _tokenAmounts,
            feeToken: localNetworkDetails.linkAddress, // LINK token
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({
                gasLimit: CUSTOM_GAS_LIMIT,
                allowOutOfOrderExecution: true
            }))
        });
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        localSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceBefore - localBalanceAfter, amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        localSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function configureTokenPool(
        uint256 fork, address localPool, uint64 remoteChainSelector, address remotePool, address remoteTokenAddress
        ) public {
            vm.selectFork(fork);
            vm.prank(owner);
            bytes memory _remotePoolAddress = abi.encode(remotePool);
            TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
            chainsToAdd[0] = TokenPool.ChainUpdate({
                remoteChainSelector: remoteChainSelector,
                allowed: true,
                remotePoolAddress: _remotePoolAddress,
                remoteTokenAddress: abi.encode(remoteTokenAddress),
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
        
    }

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia"); // create forkid for forked sepolia and we are running on it now
        arbSepoliaFork = vm.createFork("arb-sepolia"); // lly for forked arbitrum sepolia but do not select to run on it 
        // **now we have two parallel forked chains in memory.

        localSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(localSimulatorFork)); // the localsimulator contract is persistent across the two chains
        // ** it is the only contract allowed to live between the chains (or in both chains).

        // deploy and configure on sepolia (already selected)
        sepoliaNetworkDetails = localSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)), 
            new address[](0), 
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress 
        );
        sepoliaToken.grantMintAndBurnRoles(address(vault));
        sepoliaToken.grantMintAndBurnRoles(address(sepoliaPool));

        registryModuleOwnerCustomSepolia = 
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sepoliaToken)); // register EOA as token admin to enable token in CCIP

        tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistrySepolia.acceptAdminRole(address(sepoliaToken));
        
        tokenAdminRegistrySepolia.setPool(address(sepoliaToken), address(sepoliaPool)); // link tokens to pool in the token admin registry on sepolia
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepNetworkDetails.chainSelector,
            address(arbSepPool),
            address(arbSepToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
        vm.stopPrank();
        
        // deply and configure on arbsep
        vm.selectFork(arbSepoliaFork);
        arbSepNetworkDetails = localSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepToken = new RebaseToken();
        arbSepPool = new RebaseTokenPool(
            IERC20(address(arbSepToken)),
            new address[](0),
            arbSepNetworkDetails.rmnProxyAddress,
            arbSepNetworkDetails.routerAddress
        );
        arbSepToken.grantMintAndBurnRoles(address(arbSepPool));
        tokenAdminRegistryArbitrum = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistryArbitrum.acceptAdminRole(address(arbSepToken));
        vm.stopPrank();
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(SEND_VALUE, sepoliaToken.balanceOf(user));

        bridgeTokens(
            SEND_VALUE, sepoliaFork, arbSepoliaFork, sepoliaNetworkDetails, arbSepNetworkDetails, sepoliaToken, arbSepToken
        );
    }

    function testBridgeAllTokensBack() {}

    function testBridgeTwice() {}
}

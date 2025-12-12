// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRT.sol";

contract RebaseTokenTest is Test {

    RebaseToken rebaseToken;
    Vault vault;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(address(IRebaseToken(address(rebaseToken))));
        rebaseToken.grantMintAndBurnRoles(address(vault));

        payable(address(vault)).call{value: 5*1e18}("");

        vm.stopPrank();
    }

    function testLinearDeposit(uint256 amount) public {

    }
}

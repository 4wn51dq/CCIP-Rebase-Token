// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRT.sol";

contract RebaseTokenTest is Test {

    RebaseToken rebaseToken;
    Vault vault;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRoles(address(vault));

        (bool success,) = payable(address(vault)).call{value: 5*1e18}("");

        vm.stopPrank();
    }

    function testLinearDeposit(uint256 amount) public {
        amount = bound (amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();

        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        assertGt(finalBalance, middleBalance);

        assertApproxEqAbs(finalBalance-middleBalance, middleBalance-startBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound (amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimeHasPassed (uint256 depositAmount, uint256 time) public {
        depositAmount = bound(depositAmount, 100, type(uint96).max);
        time = bound(time, 1e5, type(uint128).max);

        vm.startPrank(user);
        vm.deal(user, depositAmount);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);

        vm.stopPrank();
    }
}

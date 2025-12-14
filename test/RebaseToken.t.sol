// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRT.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";


contract RebaseTokenTest is Test {

    RebaseToken rebaseToken;
    Vault vault;

    uint256 constant INTEREST_RATE = 5e10;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");
    address public user2 = makeAddr("USER2");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRoles(address(vault));

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

    // rather than guessing the amount of rewards in the vault, which is dynamic, we will create a function for that
    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    } 

    function testRedeemAfterTimeHasPassed (uint256 depositAmount, uint256 time) public {
        depositAmount = bound(depositAmount, 1e5 , 10000000 ether );
        time = bound(time, 5 minutes , 365 days * 40);

        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        uint256 _rewardAmount = depositAmount< balanceAfterSomeTime ? balanceAfterSomeTime - depositAmount : 0;
        vm.deal(owner, _rewardAmount);
        vm.prank(owner);
        addRewardsToVault(_rewardAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = address(user).balance;

        assertEq(balanceAfterSomeTime, ethBalance);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5+1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount-1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        uint256 user2balance = rebaseToken.balanceOf(user2);
        uint256 userBalance = rebaseToken.balanceOf(user);
        assertEq(userBalance, amount);
        assertEq(user2balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);
        
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2balanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2balanceAfterTransfer, user2balance + amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 interestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(interestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mintRT(user, 100, INTEREST_RATE);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burnRT(user, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.prank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.getPrincipleBalanceOfUser(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.getPrincipleBalanceOfUser(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(address(rebaseToken), vault.getRebaseTokenAddress());
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();

        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint256).max);

        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);

        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}

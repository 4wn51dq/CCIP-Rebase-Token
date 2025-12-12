//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IRebaseToken {
    function mintRT(address _to, uint256 _amount) external;
    function burnRT(address _from, uint256 _amount) external;
    function balanceOf(address _user) external view returns (uint256);
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function getUserInterestRate(address _user) external view returns (uint256);
    function getPrincipleBalanceOfUser(address _user) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IRebaseToken} from "./Interfaces/IRT.sol";

contract Vault {

    

    event DepositMade(address indexed user, uint256 amouunt);

    address private immutable i_rebaseToken;

    constructor (address rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    function deposit() external payable {
        IRebaseToken(i_rebaseToken).mintRT(msg.sender, msg.value);
        emit DepositMade(msg.sender, msg.value);
    }

    // redeem the certain amount of RTs for eth.

    function redeem(uint256 _amount) external {
        IRebaseToken(i_rebaseToken).burnRT(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        require (success, "TX unsuccessful");
    }

    function getRebaseTokenAddress() public view returns (address) {
        return i_rebaseToken;
    }

    receive() external payable {}

    fallback() external payable {}
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// #normal_token: the total supply is constant
// #rebase_token: the total supply changes based on an algorithm to reflect changes in underlying value or rewards
//                rather than the price of the tokens changing.
// tokens automatically adjust their supply to reflect the interest you earn and allow you to withdraw deposits

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title 
* @notice normal_token: the total supply is constant
* @notice rebase_token: the total supply changes based on an algorithm to reflect changes in underlying value or 
  rewards rather than the price of the tokens changing.
* @notice tokens automatically adjust their supply to reflect the interest you earn and allow you to withdraw deposits
*/

abstract contract TokenErrors {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 newInterestRate);
}

abstract contract TokenEvents {
    event InterestRateSet(uint256 newinterestRate);
}

contract RebaseToken is ERC20, TokenErrors, TokenEvents {

    uint256 public s_interestRate = 5e10; // 0.000000005 or 0.0000005% is the initial interest rate.

    mapping (address => uint256) private s_usersInterestRate; // the interest rate depends of the time at which the user makes the deposit into the vault.

    constructor() ERC20("Rebase Token", "RBT") {

    }

    function setInterestRate(uint256 _newInterestRate) external {
        if (s_interestRate> _newInterestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    // when deposit or redeems are done from the vault contract, mint and burn has to be called for the RT.

    function mintRT(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to); 
        // this function means that user has to be minted any accrued interest everytime they perform action.
        s_usersInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
        // when the user makes a deposit into the vault, that amount is under a particulat interest rate 
        // and RTs will be minted to the user accordingly.
    }

    function _mintAccruedInterest (address _user) internal {
        // principle balance: current balance of RTs minted to the user --- (1)
        // calculate their current balance including any interest (balanceOf) --- (2)
        // calculate number of tokens to be minted to the user = (2) - (1) , this is equal to the interest rate
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_usersInterestRate[_user];
    }
}
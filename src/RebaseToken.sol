//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// #normal_token: the total supply is constant
// #rebase_token: the total supply changes based on an algorithm to reflect changes in underlying value or rewards
//                rather than the price of the tokens changing.
// tokens automatically adjust their supply to reflect the interest you earn and allow you to withdraw deposits

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
* @title 
* @notice normal_token: the total supply is constant
* @notice rebase_token: the total supply changes based on an algorithm to reflect changes in underlying value or 
  rewards rather than the price of the tokens changing.
* @notice tokens automatically adjust their supply to reflect the interest you earn and allow you to withdraw deposits
* 
*/

contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 newInterestRate);

    event InterestRateSet(uint256 newinterestRate);

    uint256 private constant DECIMALS = 1e18;
    uint256 public s_interestRate = (5*DECIMALS)/1e8; // 5e8 or 0.000000005 or 0.0000005% is the initial interest rate.

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256(abi.encodePacked("MINT_AND_BURN_ROLE"));
    // bytes32 private constant DEFAULT_ADMIN_ROLE = keccak256(abi.encodePacked("DEFAULT_ADMIN_ROLE"));

    mapping(address => uint256) private s_usersInterestRate;
    // the interest rate depends of the time at which the user makes the deposit into the vault.
    mapping(address => uint256) private s_lastUpdatedTimeStampOfUser;
    // this will track the last time the user made a respective action to track their interest rate.

    constructor() ERC20("Rebase Token", "RBT") Ownable (msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINT_AND_BURN_ROLE, msg.sender);
    }

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (s_interestRate <= _newInterestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function grantMintAndBurnRoles(address _account) external onlyOwner {
        grantRole(MINT_AND_BURN_ROLE, _account);
    }

    // when deposit or redeems are done from the vault contract, mint and burn has to be called for the RT.

    function mintRT(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE){
        _mintAccruedInterest(_to);
        // this function means that user has to be minted any accrued interest everytime they perform action.
        // this minting must be done before new interest rates are given to the user.
        s_usersInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
        // when the user makes a deposit into the vault, that amount is under a particulat interest rate
        // and RTs will be minted to the user accordingly.
    }

    function burnRT(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function _calculateUserAccumulatedInterest(address _user) internal view returns (uint256) {
        return ((block.timestamp) - (s_lastUpdatedTimeStampOfUser[_user])) * (s_usersInterestRate[_user]) + DECIMALS;
        // linear interests = ((time elapsed * interest rate))
    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance and multiply it by interest rate
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterest(_user)) / DECIMALS;
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        // both the recipient and transferer should be cleared of any interest tokens that they re supposed to recieve.
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            s_usersInterestRate[_to] = s_usersInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_usersInterestRate[_recipient] = s_usersInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _mintAccruedInterest(address _user) internal {
        // principle balance: current balance of RTs minted to the user --- (1)
        // calculate their current balance including any interest (balanceOf) --- (2)
        // calculate number of tokens to be minted to the user = (2) - (1) , this is equal to the RT earned by previous interest.
        _mint(_user, balanceOf(_user) - super.balanceOf(_user));
        s_lastUpdatedTimeStampOfUser[_user] = block.timestamp;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_usersInterestRate[_user];
    }

    function getPrincipleBalanceOfUser(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
        // principle balance is the tokens minted to the user and does not include any interest.
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}

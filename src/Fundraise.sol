// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract Fundraise is ReentrancyGuard {

    /**
     * Properties
     */
    uint256 public minContributionWei;
    uint256 public maxContributionWei;
    uint256 public fundraiseSoftCapWei;
    uint256 public fundraiseHardCapWei;
    uint256 public totalRaised;
    address public owner;

    mapping(address => uint) public contributions;

    /**
     * Events
     */
    event Fundrasing(bool isOpen);
    event Contributed(address indexed sender, bool indexed isDeposit, uint256 amount, uint256 totalAmount);

    /**
     * Modifiers
     */
    modifier ownerOnly() {
        require(msg.sender == owner, 
            "no auth"
        );
        _;
    }

    modifier softCapIsReached() {
        require(fundraiseSoftCapWei < address(this).balance, 
            "soft-cap is not reached"
        );
        _;
    }

    /**
     * Set the rules of the contributions
     *
     * @param _minContribution - the minimum contribution in wei
     * @param _maxContribution - the maximum contribution in wei
     * @param _hardCap - the fundraise goal/limit (hard cap)
     */
    constructor(uint256 _minContribution, uint256 _maxContribution, uint256 _softCap, uint256 _hardCap) {
        minContributionWei = _minContribution;
        maxContributionWei = _maxContribution;
        fundraiseSoftCapWei = _softCap;
        fundraiseHardCapWei = _hardCap;
        owner = msg.sender;
        totalRaised = 0;

        emit Fundrasing(true);
    }

    // Exchange addresses will call this
    // revert it because exchanges are not eligable
    receive() external payable {
        revert();
    }

    fallback() external {
        revert();
    }

    function contributionsOf(address _contributor) public view returns(uint256) {
        return contributions[_contributor];
    }

    function profile(address _contributor) public view returns(uint256, uint) {
        uint256 contributed = contributions[_contributor];

        return (
            contributed, 
            totalRaised
        );
    }

    function amountRaised() public view returns(uint256) {
        return totalRaised;
    }

    /**
     * Contribute an amount to the fundraise effort
     */
    function contribute() public payable {
        uint256 amt = msg.value;

        uint256 currentContribution = contributions[msg.sender];
        uint256 totalAmt = currentContribution + amt;

        require(totalAmt >= minContributionWei && totalAmt <= maxContributionWei, 
                "Out of bounds contribution"
        );

        uint256 newTotalRaised = totalRaised + amt;
        require(fundraiseHardCapWei >= newTotalRaised,
            "Out of bounds contribution - hard cap exceeded"
        );

        totalRaised += amt;
        contributions[msg.sender] = totalAmt;
        emit Contributed(msg.sender, true, amt, totalAmt);
    }


    function userWithdraw(uint256 _amt) public nonReentrant() {
        uint256 contributedAmount = contributions[msg.sender];

        require(_amt <= contributedAmount, 
            "Out of bounds withdrawal"
        );

        // Can only withdraw if softcap not met
        require(fundraiseSoftCapWei > totalRaised, 
            "soft-cap reached, cannot withdraw"
        );

        uint256 newAmt = contributedAmount - _amt;

        contributions[msg.sender] = newAmt;
        totalRaised -= _amt;

        (bool success, ) = address(msg.sender).call{ value: _amt }("");
        require(success, "cannot withdraw");

        emit Contributed(msg.sender, false, _amt, newAmt);
    }

    function ownerWithdraw() public ownerOnly() softCapIsReached() {
        uint256 bal = address(this).balance;
        (bool success, ) = address(msg.sender).call{ value: bal, gas: 21000 }("");
        require(success, "cannot withdraw");
    }

}

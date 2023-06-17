// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Fundraise.sol";

contract FundraiseTest is Test {
    Fundraise public c;

    uint256 min = 0.3 ether;
    uint256 max = 5 ether;
    uint256 soft = 13 ether;
    uint256 hard = 100 ether;

    address public deployer;

    event Fundrasing(bool isOpen);
    event Contributed(address indexed sender, bool indexed isDeposit, uint256 amount, uint256 totalAmount);

    /**
     * Sets up the Fundraise.sol contract
     * minContribution = 0.3 ether
     * maxContribution = 5 ether
     * softCap = 13 ether
     * hardCap = 100 ether
     */
    function setUp() public {
        deployer = vm.addr(1);

        vm.startPrank(deployer);
        c = new Fundraise(min, max, soft, hard);
        vm.stopPrank();
    }

    /**
     * Test to ensure we can send 0.75 eth
     * 
     * This will set the address contributions record
     * to show 0.75 eth contributed.
     */
    function testContribute() public {
        address sender = vm.addr(2);
        vm.prank(sender);
        vm.deal(sender, 10 ether);

        // Setup the test to expect the event emitted
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 0.75 ether, 0.75 ether); // Deposit on contribute()

        c.contribute{value: 0.75 ether}();
        uint256 amt = c.contributionsOf(sender);
        assert(amt == 750000000000000000);
    }

    /**
     * Test to ensure we can send 0.75 eth 
     * and again send 0.55 ether
     * 
     * This will set the address contributions record
     * to show 0.75 eth contributed then 0.55eth for
     * a total of 1.3eth contributed.
     */
    function testMultipleContributions() public {
        address sender = vm.addr(3);
        vm.deal(sender, 5 ether);
        vm.startPrank(sender);

        // Setup the test to expect the event emitted
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 0.75 ether, 0.75 ether); // Deposit on contribute()
        c.contribute{value: 0.75 ether}();

        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 0.55 ether, 1.3 ether); // Deposit on contribute()
        c.contribute{value: 0.55 ether}();
        
        uint256 amt = c.contributionsOf(sender);
        assert(amt == 1.3 ether);

        vm.stopPrank();
    }

    /**
     * Test to ensure we can't send less
     * than the minContribution. In this
     * case, the min is 0.3 eth.
     *
     * The contract should revert!
     */
    function testOutOfBoundsMinContribution() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectRevert();
        c.contribute{value: 0.1 ether}();

        vm.stopPrank();
    }

    /**
     * Test to ensure we can't send more
     * than the maxContribution. In this
     * case, the min is 5 eth.
     *
     * The contract should revert!
     */
    function testOutOfBoundsMaxContribution() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectRevert();
        c.contribute{value: 7 ether}();

        vm.stopPrank();
    }

    /**
     * Test to ensure we can't send directly
     * to the contract address.
     *
     * The contract should revert!
     */
    function testReceiveFallback() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectRevert();
        (bool success, ) = address(c).call{value: 1 ether}("");
        require(success);

        uint256 bal = address(c).balance;
        assert(bal == 0);

        vm.stopPrank();
    }

    /**
     * Test to see if a user can withdraw from 
     * the contract after contributing.
     *
     * This should updates balances in the contract.
     */
    function testUserWithdrawPartialContribution() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        // Setup the test to expect the event emitted
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 2 ether, 2 ether); // Deposit on contribute()
        c.contribute{value: 2 ether}();
        
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, false, 1.2 ether, 0.8 ether); // Withdraw on userWithdraw()
        c.userWithdraw(1.2 ether);

        uint256 amt = c.contributionsOf(sender);
        assert(amt == 0.8 ether);

        vm.stopPrank();
    }

    /**
     * Test to see if a user can withdraw all their 
     * contributions from the contract after contributing.
     */
    function testUserWithdrawFullContribution() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        // Setup the test to expect the event emitted
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 2 ether, 2 ether); // Deposit on contribute()
        c.contribute{value: 2 ether}();
        
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, false, 2 ether, 0); // Withdraw on userWithdraw()
        c.userWithdraw(2 ether);
        
        uint256 amt = c.contributionsOf(sender);
        assert(amt == 0 ether);

        vm.stopPrank();
    }

    /**
     * Test to see if a user can withdraw from 
     * the contract after its reached soft cap.
     * 
     * Expect userWithdraw() to revert
     */
    function testUserWithdrawAfterSoftCap() public {

        for (uint256 i = 1; i < 5; i++) {
            address user = vm.addr(i);
            vm.startPrank(user);
            vm.deal(user, 10 ether);

            vm.expectEmit(true, true, true, false);
            emit Contributed(user, true, 5 ether, 5 ether); // Deposit on contribute()
            c.contribute{value: 5 ether}();

            vm.stopPrank();
        }

        uint256 balanceBeforeWithdrawAttempt = address(c).balance;

        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectRevert(bytes("soft-cap reached, cannot withdraw"));
        c.userWithdraw(1 ether);

        uint256 balanceAfterWithdrawAttempt = address(c).balance;
        
        assert(balanceBeforeWithdrawAttempt == balanceAfterWithdrawAttempt);
    }

    /**
     * Test to see if a user can deposit to 
     * the contract after its reached hard cap.
     * 
     * Expect contribute() to revert after hard cap
     * is reached and someone tries to send 1 eth
     */
    function testUserContributeAfterHardCap() public {
        for (uint256 i = 1; i <= 20; i++) {
            address user = vm.addr(i);
            vm.startPrank(user);
            vm.deal(user, 10 ether);

            vm.expectEmit(true, true, true, false);
            emit Contributed(user, true, 5 ether, 5 ether); // Deposit on contribute()
            c.contribute{value: 5 ether}();

            vm.stopPrank();
        }

        address sender = vm.addr(100);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectRevert(bytes("Out of bounds contribution - hard cap exceeded"));
        c.contribute{value: 1 ether }();
    }

    /**
     * Test to see if an owner can withdraw
     * before it reaches the soft cap
     */
    function testDeployerWithdrawBeforeSoftCap() public {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        // Setup the test to expect the event emitted
        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 2 ether, 2 ether); // Deposit on contribute()
        c.contribute{value: 2 ether}();

        vm.stopPrank();

        // Contract has 2 ether balance
        // Soft-cap is 13 ether

        vm.startPrank(deployer);
        
        uint256 balanceBeforeWithdrawAttempt = address(c).balance;

        vm.expectRevert(bytes("soft-cap is not reached"));
        c.ownerWithdraw();

        uint256 balanceAfterWithdrawAttempt = address(c).balance;

        assert(balanceBeforeWithdrawAttempt == balanceAfterWithdrawAttempt);

        vm.stopPrank();
    }

    /**
     * Test to see if an owner can withdraw
     * after it reaches the soft cap
     *
     * The balance of the contract will adjust but
     * the internal counter won't.
     */
    function testDeployerWithdrawAfterSoftCap() public {
        for (uint256 i = 1; i < 5; i++) {
            address user = vm.addr(i);
            vm.startPrank(user);
            vm.deal(user, 10 ether);

            vm.expectEmit(true, true, true, false);
            emit Contributed(user, true, 5 ether, 5 ether); // Deposit on contribute()
            c.contribute{value: 5 ether}();

            vm.stopPrank();
        }

        // Contract has 20 ether balance
        // Soft-cap is 13 ether
        // expect deployer to be able to withdraw

        vm.startPrank(deployer);
        
        uint256 contractBalBefore = address(c).balance;
        uint256 totalRaisedBefore = c.amountRaised();
        uint256 deployerBalBefore = address(deployer).balance;

        c.ownerWithdraw();

        uint256 contractBalAfter = address(c).balance;
        uint256 totalRaisedAfter = c.amountRaised();
        uint256 deployerBalAfter = address(deployer).balance;

        assert(contractBalBefore - 20 ether == contractBalAfter);
        assert(deployerBalBefore < deployerBalAfter);
        assert(totalRaisedBefore == totalRaisedAfter);

        vm.stopPrank();
    }

    /**
     * Test to see if a user can withdraw
     * after it reaches the soft cap
     *
     * The transaction should revert.
     */
    function testUserWithdrawAsAdminAfterSoftCap() public {
        for (uint256 i = 1; i < 5; i++) {
            address user = vm.addr(i);
            vm.startPrank(user);
            vm.deal(user, 10 ether);

            vm.expectEmit(true, true, true, false);
            emit Contributed(user, true, 5 ether, 5 ether); // Deposit on contribute()
            c.contribute{value: 5 ether}();

            vm.stopPrank();
        }

        // Contract has 20 ether balance
        // Soft-cap is 13 ether
        // expect deployer to be able to withdraw

        address randomUser = vm.addr(1337);
        vm.startPrank(randomUser);

        vm.expectRevert(bytes("no auth"));
        c.ownerWithdraw();

        vm.stopPrank();
    }

    /**
     * Test to see if profile returns the correct data
     * after one and many different contributors.
     */
    function testUserProfile() public {

        address sender = vm.addr(1);
        vm.startPrank(sender);
        vm.deal(sender, 10 ether);

        vm.expectEmit(true, true, true, false);
        emit Contributed(sender, true, 1 ether, 1 ether); // Deposit on contribute()
        c.contribute{value: 1 ether}();

        (uint256 amount, uint total) = c.profile(sender);

        assert(amount == 1 ether);
        assert(total == 1 ether);

        vm.stopPrank();

        for (uint256 i = 5; i < 10; i++) {
            address user = vm.addr(i);
            vm.startPrank(user);
            vm.deal(user, 10 ether);

            vm.expectEmit(true, true, true, false);
            emit Contributed(user, true, 3 ether, 3 ether); // Deposit on contribute()
            c.contribute{value: 3 ether}();

            vm.stopPrank();
        }

        (uint256 amountAfter, uint totalAfter) = c.profile(sender);

        uint256 bal = address(c).balance;

        assert(amountAfter == 1 ether);
        assert(totalAfter == bal);
    }
}

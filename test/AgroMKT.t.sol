// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgroFT.sol";
import "../src/AgroNFT.sol";
import "../src/AgroMKT.sol";

contract AgroTEST is Test {
    AgroFT public agroFT;
    AgroNFT public agroNFT;
    AgroMKT public agroMKT;

    address public owner = address(this);
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_SUPPLY = 1_000_000;
    uint256 public constant CEILING = 50_000 * 10**18;
    uint256 public constant TIER_1 = 100 * 10**18;

    function setUp() public {
        agroFT = new AgroFT(INITIAL_SUPPLY, treasury);
        agroNFT = new AgroNFT();
        agroMKT = new AgroMKT(
            address(agroFT),
            address(agroNFT),
            treasury,
            CEILING
        );

        agroNFT.changeOrchestrator(address(agroMKT));

        agroMKT.setTier(TIER_1, true);

        vm.prank(treasury);
        agroFT.approve(address(agroMKT), type(uint256).max);

        vm.startPrank(treasury);
        agroFT.transfer(alice, 50_000 * 10**18);
        agroFT.transfer(bob, 5_000 * 10**18);
        vm.stopPrank();
    }

    function test_lifecycle() public {
        // BATCH BUY
        uint256 amountToBuy = 2;
        uint256 baseCost = TIER_1 * amountToBuy;
        uint256 buyFee = (baseCost * 200) / 10000;
        uint256 totalCost = baseCost + buyFee;

        vm.startPrank(alice);
        agroFT.approve(address(agroMKT), totalCost);
        agroMKT.buyNextNFT(TIER_1, amountToBuy);
        vm.stopPrank();

        assertEq(agroNFT.balanceOf(alice), amountToBuy);
        assertEq(agroNFT.ownerOf(1), alice);
        assertEq(agroNFT.ownerOf(2), alice);
        assertEq(agroMKT.amountCollected(), baseCost);

        // MARKET
        uint256 salePrice = 150 * 10**18;
        uint256 tradeFee = (salePrice * 100) / 10000;
        uint256 sellerReceives = salePrice - tradeFee;

        vm.startPrank(alice);
        agroNFT.setApprovalForAll(address(agroMKT), true);
        agroMKT.saleNFT(1, salePrice);
        vm.stopPrank();

        uint256 aliceBalanceBeforeTrade = agroFT.balanceOf(alice);

        vm.startPrank(bob);
        agroFT.approve(address(agroMKT), salePrice);
        agroMKT.tradeNFT(1);
        vm.stopPrank();

        assertEq(agroNFT.ownerOf(1), bob);
        assertEq(agroFT.balanceOf(alice), aliceBalanceBeforeTrade + sellerReceives);

        // CLAIM
        agroMKT.setState(true, true, true);

        uint256 bobBalanceBeforeClaim = agroFT.balanceOf(bob);
        uint256 expectedPayout = TIER_1 + ((TIER_1 * 500) / 10000);

        uint256[] memory tokensToClaim = new uint256[](1);
        tokensToClaim[0] = 1;

        vm.prank(bob);
        agroMKT.claimNFT(tokensToClaim);

        assertEq(agroNFT.balanceOf(bob), 0);
        assertEq(agroFT.balanceOf(bob), bobBalanceBeforeClaim + expectedPayout);
        assertEq(agroMKT.amountCollected(), TIER_1);
    }

    function test_revertOnParallelMarket() public {
        vm.startPrank(alice);
        agroFT.approve(address(agroMKT), 102 * 10**18);
        agroMKT.buyNextNFT(TIER_1, 1);

        vm.expectRevert("Only Official Orchestrator is authorized");
        agroNFT.transferFrom(alice, bob, 1);
        vm.stopPrank();
    }

    function test_revertOnMint() public {
        vm.prank(alice);
        vm.expectRevert("Only Official Orchestrator is authorized");
        agroNFT.mint(alice);
    }

    function test_revertWhenExceedsCeiling() public {
        agroMKT.setCeiling(150 * 10**18);

        vm.startPrank(alice);
        agroFT.approve(address(agroMKT), 300 * 10*18);
        vm.expectRevert("Reached market ceiling");
        agroMKT.buyNextNFT(TIER_1, 2);
        vm.stopPrank();
    }
}
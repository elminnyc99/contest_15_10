// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {AlchemistV3} from "../AlchemistV3.sol";
import {AlEth} from "../external/Aleth.sol";
import {Transmuter} from "../Transmuter.sol";

import "../interfaces/ITransmuter.sol";

import "../interfaces/TransmuterErrors.sol";

contract MockAlchemist {
    AlEth collateral;

    constructor(AlEth _collateral) {
        collateral = _collateral;
    }
    
    function convertYieldTokensToUnderlying(uint256 amount) external view returns (uint256) {
        return (amount * 2e18) / 1e18;
    }

    function convertUnderlyingTokensToYield(uint256 amount) public view returns (uint256) {
        return amount * 1e18 / 2e18;
    }

    function redeem(uint256 underlying) external {
        collateral.transfer(msg.sender, convertUnderlyingTokensToYield(underlying));
    }
}

contract TransmuterTest is Test {
    AlEth public alETH;
    AlEth public collateralToken;
    AlEth public underlyingToken;
    Transmuter public transmuter;

    MockAlchemist public alchemist;

    function setUp() public {
        alETH = new AlEth();
        collateralToken = new AlEth();
        underlyingToken = new AlEth();

        alchemist = new MockAlchemist(collateralToken);

        transmuter = new Transmuter(ITransmuter.InitializationParams(address(alETH), address(this), 5256000, 0, 0, 52560000 / 2));

        transmuter.addAlchemist(address(alchemist));

        transmuter.setDepositCap(uint256(type(int256).max));

        deal(address(collateralToken), address(alchemist), type(uint256).max);
        deal(address(alETH), address(0xbeef), type(uint256).max);

        vm.prank(address(alchemist));
        collateralToken.approve(address(transmuter), type(uint256).max);

        vm.prank(address(0xbeef));
        alETH.approve(address(transmuter), type(uint256).max);
    }

    function testSetDepositCapTooLow() public { 
        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);


        vm.expectRevert();
        transmuter.setDepositCap(99e18);
    }

    function testSetTransmutaitonFeeTooHigh() public { 
        vm.expectRevert();
        transmuter.setTransmutationFee(10001);
    }

    function testSetExitFeeTooHigh() public { 
        vm.expectRevert();
        transmuter.setExitFee(10001);
    }

    function testAddAlchemist() public {
        transmuter.addAlchemist(address(0xdead));

        (uint256 index, bool active) = transmuter.alchemistEntries(address(0xdead));

        assertEq(index, 1);
        assertEq(active, true);

        assertEq(transmuter.alchemists(1), address(0xdead));
    }

    function testAddAlchemistAlreadyAdded() public {
        vm.expectRevert();
        transmuter.addAlchemist(address(alchemist));
    }

    function testRemoveAlchemist() public {
        transmuter.removeAlchemist(address(alchemist));

        (uint256 index, bool active) = transmuter.alchemistEntries(address(alchemist));

        assertEq(index, 0);
        assertEq(active, false);

        vm.expectRevert();
        transmuter.alchemists(0);
    }

    function testRemoveAlchemistNotRegistered() public {
        vm.expectRevert();
        transmuter.removeAlchemist(address(0xbee));
    }

    function testSetTransmutationTime() public {
        transmuter.setTransmutationTime(20 days);

        assertEq(transmuter.timeToTransmute(), 20 days);
    }

    function testCreateRedemption() public {
        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        Transmuter.StakingPosition[] memory positions = transmuter.getPositions(address(0xbeef), ids);

        assertEq(positions[0].amount, 100e18);
        assertEq(transmuter.totalLocked(), 100e18);
    }

    function testFuzzCreateRedemption(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < uint256(type(int256).max)/1e20);

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), amount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        Transmuter.StakingPosition[] memory positions = transmuter.getPositions(address(0xbeef), ids);

        assertEq(positions[0].amount, amount);
        assertEq(transmuter.totalLocked(), amount);
    }

    function testCreateRedemptionNoTokens() public {
        vm.expectRevert(DepositZeroAmount.selector);
        transmuter.createRedemption(address(0xbeef), address(0xadbc), 0);
    }

    function testCreateRedemptionNotRegistered() public {
        vm.expectRevert(NotRegisteredAlchemist.selector);
        transmuter.createRedemption(address(0xbeef), address(0xadbc), 100e18);
    }

    function testCreateRedemptionDepositCapReached() public {
        transmuter.setDepositCap(90e18);

        vm.expectRevert(DepositCapReached.selector);
        transmuter.createRedemption(address(0xbeef), address(0xadbc), 100e18);
    }

    function testClaimRedemptionNoPosition() public {
        vm.expectRevert(PositionNotFound.selector);
        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);
    }

    function testClaimRedemption() public {
        deal(address(collateralToken), address(transmuter), uint256(type(int256).max)/1e20);

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + 5256000);

        assertEq(collateralToken.balanceOf(address(0xbeef)), 0);
        assertEq(alETH.balanceOf(address(transmuter)), 100e18);

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(100e18));
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testClaimRedemptionFromAlchemist() public {
        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + 5256000);

        assertEq(collateralToken.balanceOf(address(0xbeef)), 0);
        assertEq(alETH.balanceOf(address(transmuter)), 100e18);

        uint256 startingBalance = collateralToken.balanceOf(address(alchemist));

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(100e18));
        assertEq(alETH.balanceOf(address(transmuter)), 0);

        assertEq(collateralToken.balanceOf(address(alchemist)), startingBalance - alchemist.convertUnderlyingTokensToYield(100e18));
    }

    function testFuzzClaimRedemption(uint256 amount) public {
        deal(address(collateralToken), address(transmuter), uint256(type(int256).max)/1e20);

        vm.assume(amount > 0);
        vm.assume(amount < uint256(type(int256).max)/1e20);

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), amount);

        vm.roll(block.number + 5256000);

        assertEq(collateralToken.balanceOf(address(0xbeef)), 0);

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(amount));
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testClaimRedemptionWithTransmuterFee() public {
        deal(address(collateralToken), address(transmuter), uint256(type(int256).max)/1e20);

        // 1% fee
        transmuter.setTransmutationFee(100);
        transmuter.setProtocolFeeReceiver(address(this));

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + 5256000);

        assertEq(collateralToken.balanceOf(address(0xbeef)), 0);

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(100e18) * 9900 / 10000);
        assertEq(collateralToken.balanceOf(address(this)), alchemist.convertUnderlyingTokensToYield(100e18) * 100 / 10000);
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testFuzzClaimRedemptionWithTransmuterFee(uint256 fee) public {
        deal(address(collateralToken), address(transmuter), uint256(type(int256).max)/1e20);

        vm.assume(fee <= 10_000);

        transmuter.setTransmutationFee(fee);
        transmuter.setProtocolFeeReceiver(address(this));

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + 5256000);

        assertEq(collateralToken.balanceOf(address(0xbeef)), 0);

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(100e18) * (10000 - fee) / 10000);
        assertEq(collateralToken.balanceOf(address(this)), alchemist.convertUnderlyingTokensToYield(100e18) * fee / 10000);
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testClaimRedemptionPremature() public {
        deal(address(collateralToken), address(transmuter), uint256(type(int256).max)/1e20);

        uint256 balanceBefore = alETH.balanceOf(address(0xbeef));

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + (5256000 / 2));

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        uint256 balanceAfter = alETH.balanceOf(address(0xbeef));

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(50e18));
        assertEq(balanceBefore - balanceAfter, 50e18);
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testFuzzClaimRedemptionPremature(uint256 time) public {
        vm.assume(time > 0);
        vm.assume(time < 5256000);

        uint256 balanceBefore = alETH.balanceOf(address(0xbeef));

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + time);

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        uint256 balanceAfter = alETH.balanceOf(address(0xbeef));

        assertApproxEqAbs(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield((100e18 * time) / 5256000), 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, (100e18 * time) / 5256000, 1);
        assertEq(alETH.balanceOf(address(transmuter)), 0);
    }

    function testClaimRedemptionPrematureWithFee() public {
        // 1%
        transmuter.setExitFee(100);

        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        uint256 balanceBefore = alETH.balanceOf(address(0xbeef));

        vm.roll(block.number + (5256000 / 2));

        vm.prank(address(0xbeef));
        transmuter.claimRedemption(1);

        uint256 balanceAfter = alETH.balanceOf(address(0xbeef));

        assertEq(collateralToken.balanceOf(address(0xbeef)), alchemist.convertUnderlyingTokensToYield(50e18));
        assertEq(balanceAfter - balanceBefore, 50e18 - (50e18 * 100 / 10000));
        assertEq(alETH.balanceOf(address(transmuter)), 0);
        assertEq(alETH.balanceOf(address(this)), 50e18 * 100 / 10000);
    }

    function testQueryGraph() external {
        vm.prank(address(0xbeef));
        transmuter.createRedemption(address(alchemist), address(collateralToken), 100e18);

        vm.roll(block.number + 5256000);

        uint256 treeQuery = transmuter.queryGraph(block.number - 5256000, block.number);

        // assertEq(treeQuery, 100e18);
    }
} // TODO: More fenwick tree tests
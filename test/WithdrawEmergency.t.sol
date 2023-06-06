// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IKSElasticLMV2} from "contracts/interfaces/IKSElasticLMV2.sol";
import {IKyberSwapFarmingToken} from "contracts/interfaces/periphery/IKyberSwapFarmingToken.sol";
import {KSElasticLMV2} from "contracts/KSElasticLMV2.sol";
import {IBasePositionManager} from "contracts/interfaces/IBasePositionManager.sol";

import {Base} from "./Base.t.sol";

contract WithdrawEmergency is Base {
    using SafeERC20 for IERC20;

    function testWithdrawEmgergencySuccess() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.warp(startTime + 1);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(jensen);
        uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);
        farmingToken.approve(address(lm), farmingTokenBalance);
        lm.withdrawEmergency(nfts);
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), jensen);
    }

    function testWithdrawEmgergencySuccessEmergencyEnabled() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(deployer);
        lm.updateEmergency(true);
        vm.stopPrank();

        vm.startPrank(jensen);
        lm.withdrawEmergency(nfts);
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), jensen);
    }

    function testWithdrawEmgergencyThenDepositAgain() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        uint256 nftId2 = nftIds[1];
        uint256[] memory nfts2 = new uint256[](1);
        nfts2[0] = nftId2;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId2);
        lm.deposit(fId, 1, nfts2, rahoz);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(jensen);
        uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);
        farmingToken.approve(address(lm), farmingTokenBalance);
        lm.withdrawEmergency(nfts);
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), jensen);

        vm.startPrank(jensen);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        (
            ,
            uint256 fIdDeposited,
            uint256 rangeIdDeposited,
            uint256 liquidityDeposited,
            uint256[] memory lastSumRewardPerLiquidity,

        ) = lm.getStake(nftId);
        farmingTokenBalance = farmingToken.balanceOf(jensen);

        assertEq(fIdDeposited, fId);
        assertEq(rangeIdDeposited, 1);
        assertEq(nft.ownerOf(nftId), address(lm));
        assertEq(liquidityDeposited, _getLiq(nftId) * 2);
        assertEq(farmingTokenBalance, _getLiq(nftId) * 2);
        assertEq(lastSumRewardPerLiquidity[0], 5166577116541744582707195283);
        assertEq(lastSumRewardPerLiquidity[1], 5166577116541744582707195283);

        uint256[] memory listNftIds = lm.getDepositedNFTs(jensen);
        assertEq(listNftIds.length, 1);
        assertEq(listNftIds[0], nftId);

        vm.warp(startTime + 2 days);

        vm.startPrank(jensen);
        lm.claimReward(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(jensen), 31991398);
        assertEq(usdt.balanceOf(jensen), 31991398);
    }

    function testWithdrawEmgergencyWithEmergencyEnabledThenDepositAgain()
        public
    {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        uint256 nftId2 = nftIds[1];
        uint256[] memory nfts2 = new uint256[](1);
        nfts2[0] = nftId2;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId2);
        lm.deposit(fId, 1, nfts2, rahoz);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(deployer);
        lm.updateEmergency(true);
        vm.stopPrank();

        vm.startPrank(jensen);
        lm.withdrawEmergency(nfts);
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), jensen);

        vm.startPrank(deployer);
        lm.updateEmergency(false);
        vm.stopPrank();

        vm.startPrank(jensen);
        nft.approve(address(lm), nftId);
        vm.expectRevert(abi.encodeWithSignature("FailToAdd()"));
        lm.deposit(fId, 1, nfts, jensen); // those nft wwithdrawEmergency with emergencyEnabled cannot join again
        vm.stopPrank();
    }

    function testWithdrawEmergencyFailNotOwner() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.warp(startTime + 1);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSignature("NotOwner()"));
        lm.withdrawEmergency(nfts);
        vm.stopPrank();
    }
}

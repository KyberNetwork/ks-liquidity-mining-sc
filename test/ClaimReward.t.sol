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

contract ClaimReward is Base {
    using SafeERC20 for IERC20;

    function testClaimRewardSuccess() public {
        uint256 nftId = nftIds[2];

        vm.warp(startTime + 1);

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        uint256 rewardAmountClaimed = 32851330; // calc manually

        assertEq(usdc.balanceOf(jensen), 0);
        assertEq(usdt.balanceOf(jensen), 0);

        vm.startPrank(jensen);
        lm.claimReward(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(jensen), rewardAmountClaimed);
        assertEq(usdt.balanceOf(jensen), rewardAmountClaimed);

        assertEq(
            usdc.balanceOf(address(lm)),
            rewardAmount - rewardAmountClaimed
        );
        assertEq(
            usdt.balanceOf(address(lm)),
            rewardAmount - rewardAmountClaimed
        );
    }

    function testClaimRewardSuccessFarmETH() public {
        phase.rewards[0].rewardToken = ETH_ADDRESS;

        vm.startPrank(deployer);
        fETHId = lm.addFarm(pool, ranges, phase, true);
        (bool success, ) = payable(address(lm)).call{value: rewardAmount}("");
        assert(success);
        usdt.safeTransfer(address(lm), rewardAmount);
        vm.stopPrank();

        uint256 nftId = nftIds[2];

        vm.warp(startTime + 1);

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fETHId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        uint256 rewardAmountClaimed = 32851330; // calc manually

        uint256 balanceETHBefore = payable(jensen).balance;
        uint256 balanceUsdtBefore = usdt.balanceOf(jensen);

        vm.startPrank(jensen);
        lm.claimReward(fETHId, nfts);
        vm.stopPrank();

        uint256 balanceETHAfter = payable(jensen).balance;
        uint256 balanceUsdtAfter = usdt.balanceOf(jensen);

        assertEq(balanceETHAfter - balanceETHBefore, 32851330);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, 32851330);

        assertEq(
            payable(address(lm)).balance,
            rewardAmount - rewardAmountClaimed
        );
        assertEq(
            usdt.balanceOf(address(lm)),
            2 * rewardAmount - rewardAmountClaimed
        );
    }
}

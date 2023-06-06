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

contract Withdraw is Base {
    using SafeERC20 for IERC20;

    function testWithdrawSuccess() public {
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
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(jensen), 32851330);
        assertEq(usdt.balanceOf(jensen), 32851330);
        assertEq(farmingToken.balanceOf(jensen), 0);
        assertEq(nft.ownerOf(nftId), jensen);
    }

    function testWithdrawMultiplePosition() public {
        uint256 nftId1 = nftIds[2];
        uint256 nftId2 = nftIds[1];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId1;

        vm.warp(startTime + 1);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId1);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId2);
        nfts[0] = nftId2;
        lm.deposit(fId, 0, nfts, rahoz);
        vm.stopPrank();

        vm.warp(startTime + 172800);

        vm.startPrank(jensen);
        uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);
        farmingToken.approve(address(lm), farmingTokenBalance);
        nfts[0] = nftId1;
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(jensen), 65267178);
        assertEq(usdt.balanceOf(jensen), 65267178);
        assertEq(nft.ownerOf(nftId1), jensen);

        vm.startPrank(rahoz);
        farmingTokenBalance = farmingToken.balanceOf(rahoz);
        farmingToken.approve(address(lm), farmingTokenBalance);
        nfts[0] = nftId2;
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(rahoz), 435863);
        assertEq(usdt.balanceOf(rahoz), 435863);
        assertEq(nft.ownerOf(nftId2), rahoz);
    }

    function testWithdrawComplexCase() public {
        uint256 nftId1 = nftIds[2];
        uint256 nftId2 = nftIds[1];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId1;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId1);
        lm.deposit(fId, 0, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(jensen);
        farmingToken.approve(address(lm), farmingToken.balanceOf(jensen));
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        vm.startPrank(jensen);
        nft.approve(address(lm), nftId1);
        lm.deposit(fId, 0, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 2 days);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId2);
        nfts[0] = nftId2;
        lm.deposit(fId, 0, nfts, rahoz);
        vm.stopPrank();

        vm.warp(startTime + 3 days);

        vm.startPrank(rahoz);
        farmingToken.approve(address(lm), farmingToken.balanceOf(rahoz));
        nfts[0] = nftId2;
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        vm.startPrank(jensen);
        farmingToken.approve(address(lm), farmingToken.balanceOf(jensen));
        nfts[0] = nftId1;
        lm.withdraw(fId, nfts);
        vm.stopPrank();
    }

    function testWithdrawFailStakeNotFound() public {
        uint256 nftId = nftIds[2];

        vm.startPrank(deployer);
        fETHId = lm.addFarm(pool, ranges, phase, true);
        vm.stopPrank();

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fETHId, 1, nfts, jensen);
        vm.stopPrank();

        vm.startPrank(jensen);
        vm.expectRevert(abi.encodeWithSignature("StakeNotFound()"));
        lm.withdraw(fId, nfts);
        vm.stopPrank();
    }

    function testWithdrawFailNotOwner() public {
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
        lm.withdraw(fId, nfts);
        vm.stopPrank();
    }

    function testWithdrawCaseDepositHalfDuration() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.warp(startTime + 1315000);

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(endTime);

        vm.startPrank(jensen);
        uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);
        farmingToken.approve(address(lm), farmingTokenBalance);
        lm.withdraw(fId, nfts);
        vm.stopPrank();

        assertEq(usdc.balanceOf(jensen), 499999999);
        assertEq(usdt.balanceOf(jensen), 499999999);
        assertEq(farmingToken.balanceOf(jensen), 0);
        assertEq(nft.ownerOf(nftId), jensen);
    }
}

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

contract ForceClosePhase is Base {
    using SafeERC20 for IERC20;

    function testForceClosePhaseSuccess() public {
        vm.startPrank(deployer);
        lm.forceClosePhase(fId);
        vm.stopPrank();
    }

    function testForceClosePhaseSuccessDeposited() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(deployer);
        lm.forceClosePhase(fId);
        vm.stopPrank();

        (
            ,
            ,
            IKSElasticLMV2.PhaseInfo memory phaseInfo,
            ,
            ,
            uint256[] memory sumRewardPerLiquidity,
            uint32 lastTouchedTime
        ) = lm.getFarm(fId);

        assertEq(sumRewardPerLiquidity[0], 138939511855686960426433007); // calculate by rewardAmount * joinedDuration(86399) * 2^96 / duration(2630000) / totalLiq(18733193066)
        assertEq(sumRewardPerLiquidity[1], 138939511855686960426433007);
        assertEq(lastTouchedTime, startTime + 1 days);
        assertEq(phaseInfo.isSettled, true);
    }

    function testForceClosePhaseFailInvalidFarm() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSignature("InvalidFarm()"));
        lm.forceClosePhase(99);
        vm.stopPrank();
    }

    function testForceClosePhaseFailPhaseEnded() public {
        vm.startPrank(deployer);
        lm.forceClosePhase(fId);
        vm.expectRevert(abi.encodeWithSignature("PhaseSettled()"));
        lm.forceClosePhase(fId);
        vm.stopPrank();
    }
}

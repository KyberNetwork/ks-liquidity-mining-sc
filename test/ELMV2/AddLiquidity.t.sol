// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IKSElasticLMV2} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';
import {KSElasticLMV2} from 'contracts/KSElasticLMV2.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';

import {Base} from './Base.t.sol';

contract AddLiquidity is Base {
  using SafeERC20 for IERC20;

  function testAddLiquiditySuccess() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    assertEq(usdc.balanceOf(jensen), 0);

    vm.warp(startTime + 1 days);

    _addLiquidity(nftId);

    vm.startPrank(jensen);
    lm.addLiquidity(fId, 1, nfts);
    vm.stopPrank();

    {
      (
        ,
        ,
        ,
        uint256 totalLiquidity,
        ,
        uint256[] memory sumRewardPerLiquidity,
        uint32 lastTouchedTime
      ) = lm.getFarm(fId);

      assertEq(sumRewardPerLiquidity[0], 138_939_511_855_686_960_426_433_007); // calculate by rewardAmount * joinedDuration(86399) * 2^48 / duration(2630000) / totalLiq(18733193066)
      assertEq(sumRewardPerLiquidity[1], 138_939_511_855_686_960_426_433_007);
      assertEq(totalLiquidity, _getLiq(nftId) * 2);
      assertEq(lastTouchedTime, startTime + 1 days);
    }

    {
      (, , , uint256 liquidityDeposited, uint256[] memory lastSumRewardPerLiquidity, ) = lm
        .getStake(nftId);
      uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

      assertEq(liquidityDeposited, _getLiq(nftId) * 2);
      assertEq(farmingTokenBalance, _getLiq(nftId) * 2);
      assertEq(lastSumRewardPerLiquidity[0], 138_939_511_855_686_960_426_433_007); // calculate by rewardAmount * joinedDuration(86399) * 2^96 / duration(2630000) / totalLiq(18733193066)
      assertEq(lastSumRewardPerLiquidity[1], 138_939_511_855_686_960_426_433_007);
    }
  }

  function testAddLiquidityFailNotDeposit() public {
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = 99;

    vm.startPrank(jensen);
    vm.expectRevert(abi.encodeWithSignature('NotOwner()'));
    lm.addLiquidity(fId, 1, nfts);
    vm.stopPrank();
  }

  function testAddLiquidityFailRangeRemoved() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.warp(startTime + 1);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    assertEq(usdc.balanceOf(jensen), 0);

    vm.warp(startTime + 1 days);

    _addLiquidity(nftId);

    vm.startPrank(deployer);
    lm.removeRange(fId, 1);
    vm.stopPrank();

    vm.startPrank(jensen);
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()'));
    lm.addLiquidity(fId, 1, nfts);
    vm.stopPrank();
  }

  function testAddLiquidityFailPhaseSettled() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.warp(startTime + 1);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    assertEq(usdc.balanceOf(jensen), 0);

    vm.warp(endTime + 1);

    _addLiquidity(nftId);

    vm.startPrank(jensen);
    vm.expectRevert(abi.encodeWithSignature('PhaseSettled()'));
    lm.addLiquidity(fId, 1, nfts);
    vm.stopPrank();
  }

  function testAddLiquidityFailPhaseForceClosed() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.warp(startTime + 1);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    assertEq(usdc.balanceOf(jensen), 0);

    vm.warp(startTime + 1 days);

    _addLiquidity(nftId);

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);
    vm.stopPrank();

    vm.startPrank(jensen);
    vm.expectRevert(abi.encodeWithSignature('PhaseSettled()'));
    lm.addLiquidity(fId, 1, nfts);
    vm.stopPrank();
  }
}

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

contract AddPhase is Base {
  using SafeERC20 for IERC20;

  function testAddPhaseSuccess() public {
    uint256 nftId = nftIds[2];

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    vm.warp(startTime + 1 days);

    uint32 newStartTime = startTime + 2 days;

    IKSElasticLMV2.PhaseInput memory phase = IKSElasticLMV2.PhaseInput({
      startTime: newStartTime,
      endTime: endTime,
      rewards: rewards
    });

    vm.startPrank(deployer);
    lm.addPhase(fId, phase);
    vm.stopPrank();

    (
      ,
      ,
      IKSElasticLMV2.PhaseInfo memory phaseInfo,
      ,
      ,
      uint256[] memory sumRewardPerLiquidity,
      uint32 lastTouchedTime
    ) = lm.getFarm(fETHId);

    assertEq(sumRewardPerLiquidity[0], 138939511855686960426433007); // calculate by rewardAmount * joinedDuration(86399) * 2^48 / duration(2630000) / totalLiq(18733193066)
    assertEq(sumRewardPerLiquidity[1], 138939511855686960426433007);
    assertEq(lastTouchedTime, newStartTime);
    assertEq(phaseInfo.startTime, newStartTime);
    assertEq(phaseInfo.endTime, endTime);
    assertEq(phaseInfo.rewards.length, 2);
    assertEq(phaseInfo.rewards[0].rewardToken, address(usdc));
    assertEq(phaseInfo.rewards[0].rewardAmount, rewardAmount);
    assertEq(phaseInfo.rewards[1].rewardToken, address(usdt));
    assertEq(phaseInfo.rewards[1].rewardAmount, rewardAmount);
    assertEq(phaseInfo.isSettled, false);
  }

  function testAddPhaseRevertInvalidFarm() public {
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IKSElasticLMV2.RewardInput[] memory rewards = new IKSElasticLMV2.RewardInput[](2);

    rewards[0] = IKSElasticLMV2.RewardInput({rewardToken: dai, rewardAmount: rewardAmount});

    rewards[1] = IKSElasticLMV2.RewardInput({rewardToken: weth, rewardAmount: rewardAmount});

    IKSElasticLMV2.PhaseInput memory phase = IKSElasticLMV2.PhaseInput({
      startTime: startTime,
      endTime: endTime,
      rewards: rewards
    });

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);

    vm.expectRevert(abi.encodeWithSignature('InvalidFarm()'));
    lm.addPhase(99, phase);

    vm.stopPrank();
  }

  function testAddPhaseRevertInvalidTime() public {
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IKSElasticLMV2.RewardInput[] memory rewards = new IKSElasticLMV2.RewardInput[](2);

    rewards[0] = IKSElasticLMV2.RewardInput({rewardToken: dai, rewardAmount: rewardAmount});
    rewards[1] = IKSElasticLMV2.RewardInput({rewardToken: weth, rewardAmount: rewardAmount});

    IKSElasticLMV2.PhaseInput memory phase = IKSElasticLMV2.PhaseInput({
      startTime: 1670570000,
      endTime: endTime,
      rewards: rewards
    });

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);

    vm.expectRevert(abi.encodeWithSignature('InvalidTime()'));
    lm.addPhase(fId, phase);
    vm.stopPrank();
  }

  function testAddPhaseRevertInvalidReward() public {
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IKSElasticLMV2.RewardInput[] memory rewards = new IKSElasticLMV2.RewardInput[](2);

    rewards[0] = IKSElasticLMV2.RewardInput({rewardToken: dai, rewardAmount: 0});
    rewards[1] = IKSElasticLMV2.RewardInput({rewardToken: weth, rewardAmount: rewardAmount});

    IKSElasticLMV2.PhaseInput memory phase = IKSElasticLMV2.PhaseInput({
      startTime: startTime,
      endTime: endTime,
      rewards: rewards
    });

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);

    vm.expectRevert(abi.encodeWithSignature('InvalidReward()'));
    lm.addPhase(fId, phase);
    vm.stopPrank();
  }
}

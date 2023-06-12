// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3Emergency is Base {
  using SafeERC20 for IERC20;

  function test_emer_amount_0() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    changePrank(rahoz);
    vm.warp(fStartTime + 10 days);
    lm.emergencyWithdraw(0);
  }

  function test_emer_normal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    changePrank(rahoz);

    lm.deposit(0, 20 ether, false);

    vm.warp(fStartTime + 10 days);

    (uint256 amount1, , ) = lm.getUserInfo(0, rahoz);
    (uint256 totalStake1, , , , , , , uint256[] memory _multipliers, , ) = lm.getPoolInfo(0);
    uint256[] memory rewards = lm.pendingRewards(0, rahoz);

    assertEq(totalStake1, 20 ether);
    assertEq(amount1, 20 ether);
    assertApproxEqAbs(rewards[0], 10 ether, 1 gwei);
    assertApproxEqAbs(rewards[1], 20 ether, 1 gwei);
    assertApproxEqAbs(rewards[2] / _multipliers[2], 1000e6, 200 wei);

    lm.emergencyWithdraw(0);
    (uint256 totalStake2, , address generatedToken, , , , , , , ) = lm.getPoolInfo(0);

    (
      uint256 amount2,
      uint256[] memory unclaimedRewards2,
      uint256[] memory lastRewardPerShares2
    ) = lm.getUserInfo(0, rahoz);

    assertEq(totalStake2, 0);
    assertEq(amount2, 0);
    assertEq(unclaimedRewards2[0], 0);
    assertEq(unclaimedRewards2[1], 0);
    assertEq(unclaimedRewards2[2], 0);
    assertEq(lastRewardPerShares2[0], 0);
    assertEq(lastRewardPerShares2[1], 0);
    assertEq(lastRewardPerShares2[2], 0);
    assertEq(_getBalanceOf(generatedToken, rahoz), 0);
  }
}

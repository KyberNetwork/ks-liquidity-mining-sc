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

contract WithdrawUnusedRewards is Base {
  using SafeERC20 for IERC20;

  function testWithdrawUnusedRewardsSuccess() public {
    uint256 balanceUsdcBefore = usdc.balanceOf(deployer);
    uint256 balanceUsdtBefore = usdt.balanceOf(deployer);

    address[] memory tokens = new address[](2);
    tokens[0] = address(usdc);
    tokens[1] = address(usdt);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = rewardAmount;
    amounts[1] = rewardAmount;

    vm.startPrank(deployer);
    lm.withdrawUnusedRewards(tokens, amounts);
    vm.stopPrank();

    uint256 balanceUsdcAfter = usdc.balanceOf(deployer);
    uint256 balanceUsdtAfter = usdt.balanceOf(deployer);

    assertEq(balanceUsdcAfter - balanceUsdcBefore, rewardAmount);
    assertEq(balanceUsdtAfter - balanceUsdtBefore, rewardAmount);

    assertEq(usdc.balanceOf(address(lm)), 0);
    assertEq(usdt.balanceOf(address(lm)), 0);
  }

  function testWithdrawUnusedRewardsSuccessETH() public {
    phase.rewards[0].rewardToken = ETH_ADDRESS;

    vm.startPrank(deployer);
    fETHId = lm.addFarm(pool, ranges, phase, true);
    (bool success, ) = payable(address(lm)).call{value: rewardAmount}('');
    assert(success);
    usdt.safeTransfer(address(lm), rewardAmount);
    vm.stopPrank();

    uint256 balanceETHBefore = payable(deployer).balance;
    uint256 balanceUsdtBefore = usdt.balanceOf(deployer);

    address[] memory tokens = new address[](2);
    tokens[0] = ETH_ADDRESS;
    tokens[1] = address(usdt);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = rewardAmount;
    amounts[1] = rewardAmount;

    vm.startPrank(deployer);
    lm.withdrawUnusedRewards(tokens, amounts);
    vm.stopPrank();

    uint256 balanceETHAfter = payable(deployer).balance;
    uint256 balanceUsdtAfter = usdt.balanceOf(deployer);

    assertEq(balanceETHAfter - balanceETHBefore, rewardAmount);
    assertEq(balanceUsdtAfter - balanceUsdtBefore, rewardAmount);

    assertEq(payable(address(lm)).balance, 0);
    assertEq(usdt.balanceOf(address(lm)), rewardAmount);
  }
}

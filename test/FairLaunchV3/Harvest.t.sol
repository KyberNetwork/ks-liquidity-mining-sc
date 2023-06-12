// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3Harvest is Base {
  using SafeERC20 for IERC20;

  function test_harvest_many_pools() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    address[] memory rewardTokens2 = new address[](2);
    uint256[] memory rewardAmounts2 = new uint256[](2);
    string[2] memory gTokenDatas2;

    (rewardTokens2, rewardAmounts2) = _getRewardData2();
    lm.addPool(POOL_KNC_USDC, fStartTime, fEndTime, rewardTokens2, rewardAmounts2, gTokenDatas2);

    _transfer(WBTC_ADDRESS, address(lm), 6000e8);
    _transfer(USDC_ADDRESS, address(lm), 6000e6);
    _transfer(ETH_ADDRESS, address(lm), 30 ether);
    _transfer(KNC_ADDRESS, address(lm), 60 ether);

    changePrank(rahoz);

    lm.deposit(0, 20 ether, false);
    lm.deposit(1, 30 ether, false);
    (uint256 totalStake1, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 totalStake2, , , , , , , , , ) = lm.getPoolInfo(1);
    assertEq(totalStake1, 20 ether);
    assertEq(totalStake2, 30 ether);

    vm.warp(fStartTime + 10 days);

    uint256 balanceEBefore = _getBalanceOf(ETH_ADDRESS, rahoz);
    uint256 balanceKBefore = _getBalanceOf(KNC_ADDRESS, rahoz);
    uint256 balanceUBefore = _getBalanceOf(USDC_ADDRESS, rahoz);
    uint256 balanceWBefore = _getBalanceOf(WBTC_ADDRESS, rahoz);

    uint256[] memory pIds = new uint256[](2);
    pIds[1] = 1;
    lm.harvestMultiplePools(pIds);

    assertApproxEqAbs(balanceEBefore + 10 ether, _getBalanceOf(ETH_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceKBefore + 20 ether, _getBalanceOf(KNC_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceUBefore + 2000e6, _getBalanceOf(USDC_ADDRESS, rahoz), 2 wei);
    assertApproxEqAbs(balanceWBefore + 2000e8, _getBalanceOf(WBTC_ADDRESS, rahoz), 2 wei);
  }
}

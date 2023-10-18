// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3Deposit is Base {
  using SafeERC20 for IERC20;

  function test_revert_deposit_invalid_pool() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    changePrank(rahoz);
    bytes4 selector = bytes4(keccak256('InvalidPool()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.deposit(1, 10 ether, false);
  }

  function test_deposit_nomal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    (uint256 totalStakeBefore, , address generatedToken, , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUBefore, , ) = lm.getUserInfo(0, rahoz);

    changePrank(rahoz);

    uint256 balanceUBefore = _getBalanceOf(POOL_MATIC_STMATIC, rahoz);
    uint256 balancePBefore = _getBalanceOf(POOL_MATIC_STMATIC, address(lm));
    uint256 balanceUGBefore = _getBalanceOf(generatedToken, rahoz);

    lm.deposit(0, 10 ether, false);

    (uint256 totalStakeAfter, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUAfter, , ) = lm.getUserInfo(0, rahoz);
    uint256 balanceUAfter = _getBalanceOf(POOL_MATIC_STMATIC, rahoz);
    uint256 balancePAfter = _getBalanceOf(POOL_MATIC_STMATIC, address(lm));
    uint256 balanceUGAfter = _getBalanceOf(generatedToken, rahoz);

    assertEq(balanceUBefore - 10 ether, balanceUAfter);
    assertEq(balancePBefore + 10 ether, balancePAfter);
    assertEq(balanceUGBefore + 10 ether, balanceUGAfter);
    assertEq(totalStakeBefore + 10 ether, totalStakeAfter);
    assertEq(amountUBefore + 10 ether, amountUAfter);
  }
}

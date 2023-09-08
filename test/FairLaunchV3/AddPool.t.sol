// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3AddPool is Base {
  using SafeERC20 for IERC20;

  function test_revert_add_invalid_time() public {
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();

    vm.warp(fStartTime - 1 days);
    bytes4 selector = bytes4(keccak256('InvalidTimes()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.addPool(
      POOL_MATIC_STMATIC,
      fStartTime,
      fStartTime,
      rewardTokens,
      rewardAmounts,
      gTokenDatas
    );

    vm.warp(fStartTime + 1);
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
  }

  function test_revert_not_operator() public {
    vm.warp(fStartTime + 1 days);
    vm.startPrank(jensen);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    vm.expectRevert('KyberSwapRole: not operator');
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
  }

  function test_revert_not_operator_2() public {
    vm.warp(fStartTime + 1 days);
    vm.startPrank(deployer);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.updateOperator(deployer, false);
    vm.expectRevert('KyberSwapRole: not operator');
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
  }

  function test_add_normal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    lm.updatePoolRewards(0);

    uint256[] memory multipliers = new uint256[](3);
    multipliers[0] = 1;
    multipliers[1] = 1;
    multipliers[2] = 1e12;

    (
      ,
      ,
      address generatedToken,
      ,
      ,
      ,
      address[] memory _rewardTokens,
      uint256[] memory _multipliers,
      ,

    ) = lm.getPoolInfo(0);
    assertEq(multipliers, _multipliers);
    assertEq(rewardTokens, _rewardTokens);
    assertTrue(generatedToken == address(0));
    assertEq(lm.poolLength(), 1);
  }

  function test_add_2_pool() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    // pool 2
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    rewardTokens = new address[](2);
    rewardAmounts = new uint256[](2);
    (rewardTokens, rewardAmounts) = _getRewardData2();

    lm.addPool(POOL_KNC_USDC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    // verify pool 2
    uint256[] memory multipliers = new uint256[](2);
    multipliers[0] = 1e10;
    multipliers[1] = 1e12;

    (
      ,
      ,
      address generatedToken,
      ,
      ,
      ,
      address[] memory _rewardTokens2,
      uint256[] memory _multipliers2,
      ,

    ) = lm.getPoolInfo(1);
    assertEq(multipliers, _multipliers2);
    assertEq(rewardTokens, _rewardTokens2);
    assertTrue(generatedToken != address(0));
    assertEq(lm.poolLength(), 2);
  }
}

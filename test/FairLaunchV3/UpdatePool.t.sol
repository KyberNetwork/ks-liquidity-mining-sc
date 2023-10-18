// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3UpdatePool is Base {
  using SafeERC20 for IERC20;

  function test_revert_update_invalid_time() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    bytes4 selector = bytes4(keccak256('InvalidTimes()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.updatePool(0, fStartTime - 2 days, rewardTokens, rewardAmounts);

    vm.warp(fStartTime + 1);
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.updatePool(0, fStartTime, rewardTokens, rewardAmounts);
  }

  function test_revert_update_invalid_pool_state() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    vm.warp(fEndTime + 1 days);
    bytes4 selector = bytes4(keccak256('InvalidPoolState()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.updatePool(0, fEndTime + 2 days, rewardTokens, rewardAmounts);
  }

  function test_revert_update_invalid_length() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    rewardAmounts = new uint256[](2);
    bytes4 selector = bytes4(keccak256('InvalidLength()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.updatePool(0, fEndTime, rewardTokens, rewardAmounts);
  }

  function test_revert_update_invalid_reward() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    rewardTokens[0] = address(0);
    rewardTokens[1] = address(1);
    rewardTokens[2] = address(2);
    bytes4 selector = bytes4(keccak256('InvalidReward()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.updatePool(0, fEndTime, rewardTokens, rewardAmounts);
  }

  function test_revert_update_not_operator() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    changePrank(jensen);
    vm.expectRevert('KyberSwapRole: not operator');
    lm.updatePool(0, fEndTime, rewardTokens, rewardAmounts);
  }

  function test_update_normal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    (, , , , , , , , uint256[] memory _rewardPerSeconds1, ) = lm.getPoolInfo(0);

    // increase end time to 1h, reward per second will be decreased
    lm.updatePool(0, fEndTime + 3600, rewardTokens, rewardAmounts);

    (
      ,
      ,
      address generatedToken,
      ,
      uint32 _endTime,
      ,
      address[] memory _rewardTokens,
      ,
      uint256[] memory _rewardPerSeconds2,

    ) = lm.getPoolInfo(0);

    assertEq(fEndTime + 3600, _endTime);
    assertEq(rewardTokens, _rewardTokens);
    assertTrue(generatedToken == address(0));
    assertGt(_rewardPerSeconds1[0], _rewardPerSeconds2[0]);
    assertGt(_rewardPerSeconds1[1], _rewardPerSeconds2[1]);
    assertGt(_rewardPerSeconds1[2], _rewardPerSeconds2[2]);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3RenewPool is Base {
  using SafeERC20 for IERC20;

  function test_revert_renew_invalid_time() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    bytes4 selector = bytes4(keccak256('InvalidTimes()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.renewPool(0, fStartTime, fStartTime, rewardAmounts);

    vm.warp(fStartTime + 1);
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.renewPool(0, fStartTime, fStartTime, rewardAmounts);
  }

  function test_revert_renew_invalid_pool_state() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    vm.warp(fStartTime + 1 days);
    bytes4 selector = bytes4(keccak256('InvalidPoolState()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.renewPool(0, fStartTime + 2 days, fEndTime, rewardAmounts);
  }

  function test_revert_renew_invalid_length() public {
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
    lm.renewPool(0, fStartTime, fEndTime, rewardAmounts);
  }

  function test_revert_renew_not_operator() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    changePrank(jensen);
    vm.expectRevert('KyberSwapRole: not operator');
    lm.renewPool(0, fStartTime, fEndTime, rewardAmounts);
  }

  function test_renew_normal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    (, , , , , , , , uint256[] memory _rewardPerSeconds1, ) = lm.getPoolInfo(0);

    rewardAmounts[0] = 60 ether;
    rewardAmounts[1] = 180 ether;
    rewardAmounts[2] = 12_000e6;
    lm.renewPool(0, fStartTime + 2 days, fEndTime + 2 days, rewardAmounts);

    (
      ,
      ,
      address generatedToken,
      uint32 _startTime,
      uint32 _endTime,
      ,
      address[] memory _rewardTokens,
      ,
      uint256[] memory _rewardPerSeconds2,

    ) = lm.getPoolInfo(0);

    assertEq(fStartTime + 2 days, _startTime);
    assertEq(fEndTime + 2 days, _endTime);
    assertEq(rewardTokens, _rewardTokens);
    assertEq(_rewardPerSeconds1[0] * 2, _rewardPerSeconds2[0]);
    assertEq(_rewardPerSeconds1[1] * 3, _rewardPerSeconds2[1]);
    assertApproxEqAbs(_rewardPerSeconds1[2] * 4, _rewardPerSeconds2[2], 2 wei);
    assertTrue(generatedToken == address(0));
  }
}

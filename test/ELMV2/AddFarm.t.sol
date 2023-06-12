// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IKSElasticLMV2} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';
import {KyberSwapFarmingToken} from 'contracts/periphery/KyberSwapFarmingToken.sol';
import {KSElasticLMV2} from 'contracts/KSElasticLMV2.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';

import {Base} from './Base.t.sol';

contract AddFarm is Base {
  using SafeERC20 for IERC20;

  function testAddFarmSuccess() public {
    phase.rewards[0].rewardToken = ETH_ADDRESS;

    vm.startPrank(deployer);
    fETHId = lm.addFarm(pool, ranges, phase, true);
    vm.stopPrank();

    (
      address poolAddress,
      IKSElasticLMV2.RangeInfo[] memory ranges,
      IKSElasticLMV2.PhaseInfo memory phaseInfo,
      uint256 liquidity,
      address farmingToken,
      ,

    ) = lm.getFarm(fETHId);

    assertEq(poolAddress, pool);

    assertEq(ranges[0].tickLower, -4);
    assertEq(ranges[0].tickUpper, 4);
    assertEq(ranges[0].weight, 1);

    assertEq(ranges[1].tickLower, -5);
    assertEq(ranges[1].tickUpper, 5);
    assertEq(ranges[1].weight, 2);

    assertEq(ranges[2].tickLower, -10);
    assertEq(ranges[2].tickUpper, 10);
    assertEq(ranges[2].weight, 3);

    assertEq(liquidity, 0);

    assertEq(phaseInfo.startTime, startTime);
    assertEq(phaseInfo.endTime, endTime);
    assertEq(phaseInfo.rewards.length, 2);
    assertEq(phaseInfo.rewards[0].rewardToken, ETH_ADDRESS);
    assertEq(phaseInfo.rewards[0].rewardAmount, rewardAmount);
    assertEq(phaseInfo.rewards[1].rewardToken, address(usdt));
    assertEq(phaseInfo.rewards[1].rewardAmount, rewardAmount);
    assertEq(phaseInfo.isSettled, false);

    assertTrue(address(farmingToken) != address(0));

    assertEq(IKyberSwapFarmingToken(farmingToken).hasRole(0x00, deployer), true);
    assertEq(
      IKyberSwapFarmingToken(farmingToken).hasRole(
        0x523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c,
        address(lm)
      ),
      true
    );
  }

  function testAddFarmRevertInvalidRangeTick() public {
    ranges[0].tickLower = 5; // wrong tick

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidRange()'));
    fId = lm.addFarm(pool, ranges, phase, true);
    vm.stopPrank();
  }

  function testAddFarmRevertInvalidRangeWeight() public {
    ranges[0].weight = 0; // wrong weight

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidRange()'));
    fId = lm.addFarm(pool, ranges, phase, true);
    vm.stopPrank();
  }

  function testAddFarmRevertInvalidPhaseStartTime() public {
    phase.startTime = 1670570000; // lower then curBlock timestamp

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidTime()'));
    fId = lm.addFarm(pool, ranges, phase, true);
    vm.stopPrank();
  }

  function testAddFarmRevertInvalidPhaseEndTime() public {
    phase.endTime = startTime; // endTime must > startTime

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidTime()'));
    fId = lm.addFarm(pool, ranges, phase, true);
    vm.stopPrank();
  }
}

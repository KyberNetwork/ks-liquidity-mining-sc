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

contract AddRange is Base {
  using SafeERC20 for IERC20;

  function testAddRangeSuccess() public {
    IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
      tickLower: -100,
      tickUpper: 100,
      weight: 10
    });

    vm.startPrank(deployer);
    lm.addRange(fId, newRange);
    vm.stopPrank();
  }

  function testAddRangeRevertInvalidFarm() public {
    IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
      tickLower: -100,
      tickUpper: 100,
      weight: 10
    });

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidFarm()'));
    lm.addRange(99, newRange);
    vm.stopPrank();
  }

  function testAddRangeRevertInvalidRange() public {
    IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
      tickLower: 200,
      tickUpper: 100,
      weight: 10
    });

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidRange()'));
    lm.addRange(fId, newRange);
    vm.stopPrank();
  }

  function testAddRangeRevertInvalidRangeWeight() public {
    IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
      tickLower: -100,
      tickUpper: 100,
      weight: 0
    });

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('InvalidRange()'));
    lm.addRange(fId, newRange);
    vm.stopPrank();
  }
}

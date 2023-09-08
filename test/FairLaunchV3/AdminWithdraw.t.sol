// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3AdminWithdraw is Base {
  using SafeERC20 for IERC20;

  function test_revert_admin_withdraw_not_allowed() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    bytes4 selector = bytes4(keccak256('NotAllowed()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.adminWithdraw(POOL_MATIC_STMATIC, 1 ether);
  }

  function test_admin_withdraw_normal() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    _transfer(KNC_ADDRESS, address(lm), 60 ether);

    lm.adminWithdraw(KNC_ADDRESS, 60 ether);
  }

  function test_revert_admin_withdraw_not_have_role() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);
    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    (rewardTokens, rewardAmounts) = _getRewardData3();
    string[2] memory gTokenDatas;

    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    _transfer(KNC_ADDRESS, address(lm), 60 ether);
    changePrank(rahoz);
    vm.expectRevert('KyberSwapRole: not owner');
    lm.adminWithdraw(KNC_ADDRESS, 60 ether);
  }
}

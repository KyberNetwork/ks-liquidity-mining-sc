// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

import {Base} from './Base.t.sol';

contract F3Withdraw is Base {
  using SafeERC20 for IERC20;

  function test_revert_withdraw_insuffient_amount() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);

    changePrank(rahoz);
    lm.deposit(0, 10 ether, false);

    bytes4 selector = bytes4(keccak256('InsufficientAmount()'));
    vm.expectRevert(abi.encodeWithSelector(selector));
    lm.withdraw(0, 11 ether);
  }

  function test_revert_not_enough_generatedToken() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';
    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    (, , address generatedToken, , , , , , , ) = lm.getPoolInfo(0);

    changePrank(rahoz);
    lm.deposit(0, 10 ether, false);

    assertEq(_getBalanceOf(generatedToken, rahoz), 10 ether);

    // transfer generated token to other, not enough balance to burn later
    IERC20(generatedToken).transfer(jensen, 1 ether);

    vm.expectRevert('ERC20: burn amount exceeds balance');
    lm.withdraw(0, 10 ether);
  }

  function test_nomal_withdraw() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    _transfer(ETH_ADDRESS, address(lm), 30 ether);
    _transfer(KNC_ADDRESS, address(lm), 60 ether);
    _transfer(USDC_ADDRESS, address(lm), 3000e6);

    (, , address generatedToken, , , , , , , ) = lm.getPoolInfo(0);

    changePrank(rahoz);

    lm.deposit(0, 10 ether, false);
    vm.warp(fStartTime + 10 days);

    (uint256 totalStakeBefore, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUBefore, , ) = lm.getUserInfo(0, rahoz);
    uint256 balanceUBefore = _getBalanceOf(POOL_MATIC_STMATIC, rahoz);
    uint256 balancePBefore = _getBalanceOf(POOL_MATIC_STMATIC, address(lm));
    uint256 balanceUGBefore = _getBalanceOf(generatedToken, rahoz);
    uint256 balanceR1Before = _getBalanceOf(ETH_ADDRESS, rahoz);
    uint256 balanceR2Before = _getBalanceOf(KNC_ADDRESS, rahoz);
    uint256 balanceR3Before = _getBalanceOf(USDC_ADDRESS, rahoz);

    lm.withdraw(0, 10 ether);

    (uint256 totalStakeAfter, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUAfter, , ) = lm.getUserInfo(0, rahoz);

    assertEq(balanceUBefore + 10 ether, _getBalanceOf(POOL_MATIC_STMATIC, rahoz));
    assertEq(balancePBefore - 10 ether, _getBalanceOf(POOL_MATIC_STMATIC, address(lm)));
    assertEq(balanceUGBefore - 10 ether, _getBalanceOf(generatedToken, rahoz));
    assertEq(totalStakeBefore - 10 ether, totalStakeAfter);
    assertEq(amountUBefore - 10 ether, amountUAfter);

    assertApproxEqAbs(balanceR1Before + 10 ether, _getBalanceOf(ETH_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceR2Before + 20 ether, _getBalanceOf(KNC_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceR3Before + 1000e6, _getBalanceOf(USDC_ADDRESS, rahoz), 200 wei);
  }

  function test_nomal_withdrawAll() public {
    vm.warp(fStartTime - 1 days);
    vm.startPrank(deployer);

    address[] memory rewardTokens = new address[](3);
    uint256[] memory rewardAmounts = new uint256[](3);
    string[2] memory gTokenDatas;
    gTokenDatas[0] = 'G1 Token';
    gTokenDatas[1] = 'G1';

    (rewardTokens, rewardAmounts) = _getRewardData3();
    lm.addPool(POOL_MATIC_STMATIC, fStartTime, fEndTime, rewardTokens, rewardAmounts, gTokenDatas);
    _transfer(ETH_ADDRESS, address(lm), 30 ether);
    _transfer(KNC_ADDRESS, address(lm), 60 ether);
    _transfer(USDC_ADDRESS, address(lm), 3000e6);

    (, , address generatedToken, , , , , , , ) = lm.getPoolInfo(0);

    changePrank(rahoz);

    lm.deposit(0, 10 ether, false);
    vm.warp(fStartTime + 20 days);

    (uint256 totalStakeBefore, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUBefore, , ) = lm.getUserInfo(0, rahoz);
    uint256 balanceUBefore = _getBalanceOf(POOL_MATIC_STMATIC, rahoz);
    uint256 balancePBefore = _getBalanceOf(POOL_MATIC_STMATIC, address(lm));
    uint256 balanceUGBefore = _getBalanceOf(generatedToken, rahoz);
    uint256 balanceR1Before = _getBalanceOf(ETH_ADDRESS, rahoz);
    uint256 balanceR2Before = _getBalanceOf(KNC_ADDRESS, rahoz);
    uint256 balanceR3Before = _getBalanceOf(USDC_ADDRESS, rahoz);

    lm.withdrawAll(0);

    (uint256 totalStakeAfter, , , , , , , , , ) = lm.getPoolInfo(0);
    (uint256 amountUAfter, , ) = lm.getUserInfo(0, rahoz);

    assertEq(balanceUBefore + 10 ether, _getBalanceOf(POOL_MATIC_STMATIC, rahoz));
    assertEq(balancePBefore - 10 ether, _getBalanceOf(POOL_MATIC_STMATIC, address(lm)));
    assertEq(balanceUGBefore - 10 ether, _getBalanceOf(generatedToken, rahoz));
    assertEq(totalStakeBefore - 10 ether, totalStakeAfter);
    assertEq(amountUBefore - 10 ether, amountUAfter);

    assertApproxEqAbs(balanceR1Before + 20 ether, _getBalanceOf(ETH_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceR2Before + 40 ether, _getBalanceOf(KNC_ADDRESS, rahoz), 1 gwei);
    assertApproxEqAbs(balanceR3Before + 2000e6, _getBalanceOf(USDC_ADDRESS, rahoz), 200 wei);
  }
}

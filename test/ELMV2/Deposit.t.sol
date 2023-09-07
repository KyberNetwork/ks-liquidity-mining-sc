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

contract Deposit is Base {
  using SafeERC20 for IERC20;

  function checkPool(
    address pAddress,
    address nftContract,
    uint256 nftId
  ) internal view returns (bool) {
    IBasePositionManager.Position memory pData = _getPositionFromNFT(nftContract, nftId);
    return IBasePositionManager(nftContract).addressToPoolId(pAddress) == pData.poolId;
  }

  function getPositionInfo(
    address nftContract,
    uint256 nftId
  ) internal view returns (int24, int24, uint128) {
    IBasePositionManager.Position memory pData = _getPositionFromNFT(nftContract, nftId);
    return (pData.tickLower, pData.tickUpper, pData.liquidity);
  }

  function _getPositionFromNFT(
    address nftContract,
    uint256 nftId
  ) internal view returns (IBasePositionManager.Position memory) {
    (IBasePositionManager.Position memory pData, ) = IBasePositionManager(nftContract).positions(
      nftId
    );
    return pData;
  }

  function testDepositSuccess() public {
    uint256 nftId = nftIds[2];

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 1);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId) * 2);
    assertEq(farmingTokenBalance, _getLiq(nftId) * 2);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(lastSumRewardPerLiquidity[1], 0);

    uint256[] memory listNftIds = lm.getDepositedNFTs(jensen);
    assertEq(listNftIds.length, 1);
    assertEq(listNftIds[0], nftId);
  }

  function testDepositFailInvalidFarm() public {
    uint256 nftId = nftIds[2];

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    vm.expectRevert(abi.encodeWithSignature('FarmNotFound()'));
    lm.deposit(99, 1, nfts, jensen);
    vm.stopPrank();
  }

  function testDepositFailInvalidPosition() public {
    uint256 nftId = 100;
    address owner = nft.ownerOf(nftId);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.prank(owner);
    nft.transferFrom(owner, deployer, nftId);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    vm.expectRevert(abi.encodeWithSignature('PositionNotEligible()'));
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();
  }

  function testDepositFailNoLiquidity() public {
    uint256 nftId = 16;
    address owner = nft.ownerOf(nftId);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.prank(owner);
    nft.transferFrom(owner, deployer, nftId);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    vm.expectRevert(abi.encodeWithSignature('PositionNotEligible()'));
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();
  }

  function testDepositFailInvalidRange() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()'));
    lm.deposit(fId, 99, nfts, jensen);
    vm.stopPrank();
  }

  function testDepositFailDeletedRange() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.startPrank(deployer);
    lm.removeRange(fId, 1);
    nft.approve(address(lm), nftId);
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()'));
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();
  }

  function testDepositWhenFarmAlreadyStarted() public {
    uint256 nftId = nftIds[2];
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    vm.warp(startTime + 1 days); // 1 day

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 1);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId) * 2);
    assertEq(farmingTokenBalance, _getLiq(nftId) * 2);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(lastSumRewardPerLiquidity[1], 0);
  }

  function testDepositMultiplePosition() public {
    uint256 nftId1 = nftIds[2];
    uint256 nftId2 = nftIds[1];

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId1;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId1);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    vm.warp(startTime + 1 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    nfts[0] = nftId2;
    lm.deposit(fId, 0, nfts, jensen);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId2);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(liquidityDeposited, _getLiq(nftId2));
    assertEq(farmingTokenBalance, _getLiq(nftId1) * 2 + _getLiq(nftId2));
    assertEq(lastSumRewardPerLiquidity[0], 138_939_511_855_686_960_426_433_007); // calculate by rewardAmount * joinedDuration(86399) * 2^96 / duration(2630000) / totalLiq(18733193066)
    assertEq(lastSumRewardPerLiquidity[1], 138_939_511_855_686_960_426_433_007);
  }

  function testDepositMultiplePositionAtTheSameTime() public {
    uint256 nftId1 = nftIds[2];
    uint256 nftId2 = nftIds[1];

    uint256[] memory nfts = new uint256[](2);
    nfts[0] = nftId1;
    nfts[1] = nftId2;

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId1);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 1, nfts, jensen);
    vm.stopPrank();

    vm.warp(startTime + 1 days);

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId2);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 1);
    assertEq(liquidityDeposited, _getLiq(nftId2) * 2);
    assertEq(farmingTokenBalance, _getLiq(nftId1) * 2 + _getLiq(nftId2) * 2);
    assertEq(lastSumRewardPerLiquidity[0], 0); // calculate by rewardAmount * joinedDuration(86399) * 2^96 / duration(2630000) / totalLiq(18733193066)
    assertEq(lastSumRewardPerLiquidity[1], 0);
  }
}

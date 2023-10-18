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
import {IFactory} from 'contracts/interfaces/IFactory.sol';

import {Base} from './Base.t.sol';

contract UnwrapNative is Base {
  using SafeERC20 for IERC20;

  IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  address wethWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

  address wethUsdtPool = 0x7d697d789ee19bc376474E0167BADe9535A28CF4;
  address wstethWethPool = 0xeBfE63Ba0264aD639B3C41d2bfE1aD708F683bc8;

  uint256 fWethId;

  uint256 nftId = 1; //belongs to poolId 1, liquidity > 0
  uint128 nftLiq = 117_546_247_299_525;
  uint256 amountWethWhenRemoveLiquidity = 784_318_538_031_233_553; //get by call directly to posManager
  uint256 amountWethWhenClaimFee = 17_825_205_570_209_216; // get by call directly to posManager

  uint256 fWethId2;
  uint256 nftId2 = 96;
  uint128 nft2Liq = 226_263_781_797_256_566_635_813;
  uint256 amountWethWhenRemoveLiquidity2 = 1_933_092_082_103_344_048_210;
  uint256 amountWethWhenClaimFee2 = 3_359_677_506_938_625_020;

  function setUp() public override {
    super.setUp();

    vm.startPrank(deployer);
    ranges[1].tickLower = -201_000;
    ranges[1].tickUpper = -200_000;
    fWethId = lm.addFarm(wethUsdtPool, ranges, phase, true);

    ranges[1].tickLower = 700;
    ranges[1].tickUpper = 900;
    fWethId2 = lm.addFarm(wstethWethPool, ranges, phase, true);
    vm.stopPrank();

    vm.startPrank(wethWhale);
    weth.safeTransfer(address(lm), rewardAmount * 2);
    vm.stopPrank();

    vm.label(address(weth), 'WETH');
    vm.label(wethUsdtPool, 'Pool ID 1');
    vm.label(wstethWethPool, 'Pool ID 22');

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nftId;

    address nftOwner = nft.ownerOf(nftId);

    vm.startPrank(nftOwner);
    nft.approve(address(lm), nftId);
    lm.deposit(fWethId, 1, nfts, jensen);
    vm.stopPrank();

    address nftOwner2 = nft.ownerOf(nftId2);
    nfts[0] = nftId2;

    vm.startPrank(nftOwner2);
    nft.approve(address(lm), nftId2);
    lm.deposit(fWethId2, 1, nfts, jensen);
    vm.stopPrank();
  }

  function testSetUp() public override {
    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);

    assertEq(fIdDeposited, fWethId);
    assertEq(rangeIdDeposited, 1);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId) * 2);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(lastSumRewardPerLiquidity[1], 0);

    (, fIdDeposited, rangeIdDeposited, liquidityDeposited, lastSumRewardPerLiquidity, ) = lm
      .getStake(nftId2);

    assertEq(fIdDeposited, fWethId2);
    assertEq(rangeIdDeposited, 1);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId2) * 2);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(lastSumRewardPerLiquidity[1], 0);

    uint256[] memory listNftIds = lm.getDepositedNFTs(jensen);
    assertEq(listNftIds.length, 2);
    assertEq(listNftIds[0], nftId);
    assertEq(listNftIds[1], nftId2);
  }

  function testUnwrapNativeRemoveAllLiquidity() public {
    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.removeLiquidity(
      nftId,
      nftLiq,
      0,
      0,
      block.timestamp + 3600,
      _buildFlags(false, false, false, true)
    );
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    assertEq(balanceAfter - balanceBefore, amountWethWhenRemoveLiquidity);
  }

  function testUnwrapNativeRemoveHalfLiquidity() public {
    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.removeLiquidity(
      nftId,
      nftLiq / 2,
      0,
      0,
      block.timestamp + 3600,
      _buildFlags(false, false, false, true)
    );
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    assertApproxEqAbs(balanceAfter - balanceBefore, amountWethWhenRemoveLiquidity / 2, 10_000);
  }

  function testUnwrapNativeRemoveAllLiquidityAndClaimFee() public {
    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.removeLiquidity(
      nftId,
      nftLiq,
      0,
      0,
      block.timestamp + 3600,
      _buildFlags(true, false, false, true)
    );
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    assertEq(balanceAfter - balanceBefore, amountWethWhenRemoveLiquidity + amountWethWhenClaimFee);
  }

  function testUnwrapNativeRemoveAllLiquidityAnotherFarm() public {
    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.removeLiquidity(
      nftId2,
      nft2Liq,
      0,
      0,
      block.timestamp + 3600,
      _buildFlags(false, false, false, true)
    );
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    assertEq(balanceAfter - balanceBefore, amountWethWhenRemoveLiquidity2);
  }

  function testUnwrapNativeRemoveAllLiquidityAndClaimFeeAnotherFarm() public {
    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.removeLiquidity(
      nftId2,
      nft2Liq,
      0,
      0,
      block.timestamp + 3600,
      _buildFlags(true, false, false, true)
    );
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    assertEq(
      balanceAfter - balanceBefore,
      amountWethWhenRemoveLiquidity2 + amountWethWhenClaimFee2
    );
  }
}

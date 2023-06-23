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

contract GetAmountsFromFarmingToken is Base {
  using SafeERC20 for IERC20;

  function testGetAmountsFromFarmingTokenSuccess() public {
    uint256 nftId = nftIds[2];
    uint256 amountUsdcShouldBe = 5124844; //get from calling directly to posManager
    uint256 amountUsdtShouldBe = 4707024; //get from calling directly to posManager

    (IBasePositionManager.Position memory pos, ) = IBasePositionManager(address(nft)).positions(
      nftId
    );

    (uint256 amount0, uint256 amount1) = helper.getAmountsFromFarmingToken(
      lm,
      fId,
      0,
      pos.liquidity,
      pos.tickLower,
      pos.tickUpper
    );

    assertEq(amount0, amountUsdcShouldBe);
    assertEq(amount1, amountUsdtShouldBe);
  }
}

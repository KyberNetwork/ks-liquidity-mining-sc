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
import {AddFarm} from './AddFarm.t.sol';
import {AddPhase} from './AddPhase.t.sol';
import {AddRange} from './AddRange.t.sol';
import {ClaimReward} from './ClaimReward.t.sol';
import {Deposit} from './Deposit.t.sol';
import {ForceClosePhase} from './ForceClosePhase.t.sol';
import {RemoveRange} from './RemoveRange.t.sol';
import {AddLiquidity} from './AddLiquidity.t.sol';
import {RemoveLiquidity} from './RemoveLiquidity.t.sol';
import {Withdraw} from './Withdraw.t.sol';
import {WithdrawUnusedRewards} from './WithdrawUnusedRewards.t.sol';
import {GetFarm} from './GetFarm.t.sol';
import {TransferAdmin} from './TransferAdmin.t.sol';
import {UpdateOperator} from './UpdateOperator.t.sol';
import {UpdateHelper} from './UpdateHelper.t.sol';
import {WithdrawEmergency} from './WithdrawEmergency.t.sol';

contract Full is
  Base,
  AddFarm,
  AddPhase,
  AddRange,
  ClaimReward,
  Deposit,
  ForceClosePhase,
  GetFarm,
  RemoveRange,
  TransferAdmin,
  AddLiquidity,
  RemoveLiquidity,
  UpdateOperator,
  UpdateHelper,
  Withdraw,
  WithdrawEmergency,
  WithdrawUnusedRewards
{
  using SafeERC20 for IERC20;
}

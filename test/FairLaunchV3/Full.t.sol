// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {F3AddPool} from './AddPool.t.sol';
import {Base} from './Base.t.sol';
import {F3Deposit} from './Deposit.t.sol';
import {F3Emergency} from './Emergency.t.sol';
import {F3Harvest} from './Harvest.t.sol';
import {F3RenewPool} from './RenewPool.t.sol';
import {F3Withdraw} from './Withdraw.t.sol';
import {F3UpdatePool} from './UpdatePool.t.sol';
import {F3AdminWithdraw} from './AdminWithdraw.t.sol';

contract F3Full is
  F3AddPool,
  F3Deposit,
  F3Emergency,
  F3Harvest,
  F3RenewPool,
  F3Withdraw,
  F3UpdatePool,
  F3AdminWithdraw
{}

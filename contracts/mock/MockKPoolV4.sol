// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockKPoolV4 {
  IERC20 public token0;
  IERC20 public token1;

  constructor(IERC20 _token0, IERC20 _token1) {
    token0 = _token0;
    token1 = _token1;
  }
}

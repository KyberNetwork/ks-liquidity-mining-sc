// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

contract KyberSwapFarmingToken is ERC20, ERC20Burnable, ERC20Permit {
  address public operator;

  error Forbidden();

  modifier isOperator() {
    if (msg.sender != operator) revert Forbidden();
    _;
  }

  constructor() ERC20('KyberSwapFarmingToken', 'KS-FT') ERC20Permit('KyberSwapFarmingToken') {
    operator = msg.sender;
  }

  function mint(address account, uint256 amount) public isOperator {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external isOperator {
    _burn(account, amount);
  }
}

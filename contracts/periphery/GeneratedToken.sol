// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IGeneratedToken} from 'contracts/interfaces/periphery/IGeneratedToken.sol';

contract GeneratedToken is ERC20, IGeneratedToken {
  address internal deployer;

  modifier onlyDeployer() {
    require(msg.sender == deployer, 'unauthorized');
    _;
  }

  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    deployer = msg.sender;
  }

  function mint(address account, uint256 amount) external override onlyDeployer {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external override onlyDeployer {
    _burn(account, amount);
  }
}

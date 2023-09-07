// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract KyberSwapRole {
  address public owner;
  bool public isLogicEnabled;
  mapping(address => bool) public operators;
  mapping(address => bool) public guardians;

  event TransferOwner(address indexed newOwner);
  event UpdateOperator(address indexed operator, bool grantOrRevoke);
  event UpdateGuardian(address indexed guardian, bool grantOrRevoke);
  event UpdateLogic(bool isEnbaled);

  modifier onlyOwner() {
    require(msg.sender == owner, 'KyberSwapRole: not owner');
    _;
  }

  modifier onlyOperator() {
    require(operators[msg.sender], 'KyberSwapRole: not operator');
    _;
  }

  modifier onlyGuardian() {
    require(guardians[msg.sender], 'KyberSwapRole: not guardian');
    _;
  }

  modifier onlyEnabled() {
    require(isLogicEnabled, 'KyberSwapRole: not enabled');
    _;
  }

  constructor() {
    owner = msg.sender;
    isLogicEnabled = true;
  }

  function transferOwner(address _owner) external virtual onlyOwner {
    require(_owner != address(0), 'KyberSwapRole: forbidden');
    owner = _owner;
    emit TransferOwner(_owner);
  }

  function updateOperator(address user, bool grantOrRevoke) external onlyOwner {
    operators[user] = grantOrRevoke;
    emit UpdateOperator(user, grantOrRevoke);
  }

  function updateGuardian(address user, bool grantOrRevoke) external onlyOwner {
    guardians[user] = grantOrRevoke;
    emit UpdateGuardian(user, grantOrRevoke);
  }

  function enableLogic() external onlyOwner {
    isLogicEnabled = true;
    emit UpdateLogic(true);
  }

  function disableLogic() external onlyGuardian {
    isLogicEnabled = false;
    emit UpdateLogic(false);
  }
}

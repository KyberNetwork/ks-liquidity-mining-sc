// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

abstract contract FoundryHelper is Test {
  address public deployer;
  uint256 public privDeployer;
  address public user1;
  address public user2;
  address public user3;
  address public user4;
  uint256 public privUser1;
  uint256 public privUser2;
  uint256 public privUser3;
  uint256 public privUser4;
  uint256 public MAX_UINT256 = type(uint256).max;
  address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  modifier asPrankedUser(address user) {
    vm.startPrank(user);
    _;
    vm.stopPrank();
  }

  modifier asHoaxUser(address user, uint256 amount) {
    startHoax(user, amount);
    _;
    vm.stopPrank();
  }

  function _setupAccount() internal {
    (deployer, privDeployer) = makeAddrAndKey('Deployer');
    (user1, privUser1) = makeAddrAndKey('user1');
    (user2, privUser2) = makeAddrAndKey('user2');
    (user3, privUser3) = makeAddrAndKey('user3');
    (user4, privUser4) = makeAddrAndKey('user4');
  }

  //restricted to pure to avoid noisy warnings
  function _signMessage(bytes32 message, uint256 _key) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, keccak256(abi.encodePacked(message)));
    return abi.encodePacked(r, s, v);
  }

  function _computeHash(bytes32 message) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(message));
  }

  function _toArray(uint256 a) internal pure returns (uint256[] memory array) {
    array = new uint256[](1);

    array[0] = a;
  }

  function _toArray(address a) internal pure returns (address[] memory array) {
    array = new address[](1);

    array[0] = a;
  }

  function _toArray(uint256 a, uint256 b) internal pure returns (uint256[] memory array) {
    array = new uint256[](2);

    array[0] = a;
    array[1] = b;
  }

  function _toArray(
    uint256 a,
    uint256 b,
    uint256 c
  ) internal pure returns (uint256[] memory array) {
    array = new uint256[](3);

    array[0] = a;
    array[1] = b;
    array[2] = c;
  }
}

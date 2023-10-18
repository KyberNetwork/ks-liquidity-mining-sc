// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import 'contracts/KSFairLaunchV3.sol';

contract DeployFair3 is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    KSFairLaunchV3 farm = new KSFairLaunchV3();

    console.log('Farm address: ', address(farm));

    vm.stopBroadcast();
  }
}

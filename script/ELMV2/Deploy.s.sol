// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import 'contracts/KSElasticLMV2.sol';
import 'contracts/KSElasticLMHelper.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {KyberSwapFarmingToken} from 'contracts/periphery/KyberSwapFarmingToken.sol';
import {IKSElasticLMHelper} from 'contracts/interfaces/IKSElasticLMHelper.sol';

contract Deploy is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    string memory deployFile = './script/ELMV2/input/input.json';

    vm.startBroadcast(deployerPrivateKey);

    string memory deployData = vm.readFile(deployFile);
    address nftAddress = abi.decode(vm.parseJson(deployData, '.NFT'), (address));
    bool isDeployHelper = abi.decode(vm.parseJson(deployData, '.isDeployHelper'), (bool));

    address helperSC;

    if (isDeployHelper) {
      helperSC = address(new KSElasticLMHelper());
    } else {
      helperSC = abi.decode(vm.parseJson(deployData, '.Helper'), (address));
    }

    KSElasticLMV2 farm = new KSElasticLMV2(IERC721(nftAddress), IKSElasticLMHelper(helperSC));
    farm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);

    console.log('Farm address: ', address(farm));
    console.log('Helper address: ', helperSC);

    vm.stopBroadcast();
  }
}

contract DeployHelper is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    address helperSC = address(new KSElasticLMHelper());

    console.log('Helper address: ', helperSC);

    vm.stopBroadcast();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {KSFairLaunchV3} from 'contracts/KSFairLaunchV3.sol';

contract Base is Test {
  using SafeERC20 for IERC20;

  string MAINNET_RPC_URL = vm.envString('POLYGON_NODE_URL');

  address public ETH_ADDRESS = address(0);
  address public KNC_ADDRESS = 0x1C954E8fe737F99f68Fa1CCda3e51ebDB291948C;
  address public USDC_ADDRESS = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address public WBTC_ADDRESS = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6; // decimal 8

  address public POOL_MATIC_STMATIC = 0x0cFb295296C7869E5DF0e8a4187b554167287Cc2;
  address public POOL_KNC_USDC = 0x4B440a7DE0Ab7041934d0c171849A76CC33234Fa;
  address public STMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;

  KSFairLaunchV3 public lm;

  address public deployer;
  address public jensen;
  address public rahoz;

  uint32 fStartTime = 1686006366;
  uint32 fEndTime = fStartTime + 30 days;
  uint256 MOCK_BALANCE = 10000 ether;
  uint256 MAX_UINT = type(uint256).max;

  uint256 mainnetFork;

  function setUp() public virtual {
    mainnetFork = vm.createFork(MAINNET_RPC_URL);
    vm.selectFork(mainnetFork);
    vm.rollFork(43551159);

    deployer = makeAddr('Deployer');
    jensen = makeAddr('Jensen');
    rahoz = makeAddr('Rahoz');
    vm.label(USDC_ADDRESS, 'USDC');
    vm.label(KNC_ADDRESS, 'KNC');
    vm.label(WBTC_ADDRESS, 'WBTC');
    vm.label(ETH_ADDRESS, 'ETH Native');
    vm.label(STMATIC, 'stMatic');

    vm.startPrank(deployer);
    deal(deployer, MOCK_BALANCE);
    deal(rahoz, MOCK_BALANCE);
    deal(jensen, MOCK_BALANCE);
    deal(POOL_MATIC_STMATIC, deployer, MOCK_BALANCE);
    deal(POOL_MATIC_STMATIC, rahoz, MOCK_BALANCE);
    deal(POOL_MATIC_STMATIC, jensen, MOCK_BALANCE);
    deal(POOL_KNC_USDC, deployer, MOCK_BALANCE);
    deal(POOL_KNC_USDC, rahoz, MOCK_BALANCE);
    deal(POOL_KNC_USDC, jensen, MOCK_BALANCE);
    deal(KNC_ADDRESS, deployer, MOCK_BALANCE);
    deal(KNC_ADDRESS, rahoz, MOCK_BALANCE);
    deal(KNC_ADDRESS, jensen, MOCK_BALANCE);
    deal(USDC_ADDRESS, deployer, MOCK_BALANCE);
    deal(USDC_ADDRESS, rahoz, MOCK_BALANCE);
    deal(USDC_ADDRESS, jensen, MOCK_BALANCE);
    deal(WBTC_ADDRESS, deployer, MOCK_BALANCE);
    deal(WBTC_ADDRESS, rahoz, MOCK_BALANCE);
    deal(WBTC_ADDRESS, jensen, MOCK_BALANCE);
    deal(STMATIC, deployer, MOCK_BALANCE);
    deal(STMATIC, rahoz, MOCK_BALANCE);
    deal(STMATIC, jensen, MOCK_BALANCE);

    lm = new KSFairLaunchV3();
    IERC20(POOL_MATIC_STMATIC).approve(address(lm), MAX_UINT);
    IERC20(POOL_KNC_USDC).approve(address(lm), MAX_UINT);
    changePrank(jensen);
    IERC20(POOL_MATIC_STMATIC).approve(address(lm), MAX_UINT);
    IERC20(POOL_KNC_USDC).approve(address(lm), MAX_UINT);
    changePrank(rahoz);
    IERC20(POOL_MATIC_STMATIC).approve(address(lm), MAX_UINT);
    IERC20(POOL_KNC_USDC).approve(address(lm), MAX_UINT);

    vm.label(address(lm), 'FarmSC');
    vm.stopPrank();
  }

  function _getRewardData2()
    public
    view
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
  {
    rewardTokens = new address[](2);
    rewardAmounts = new uint256[](2);
    rewardTokens[0] = WBTC_ADDRESS;
    rewardTokens[1] = USDC_ADDRESS;
    rewardAmounts[0] = 6000e8;
    rewardAmounts[1] = 3000e6;
  }

  function _getRewardData3()
    public
    view
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
  {
    rewardTokens = new address[](3);
    rewardAmounts = new uint256[](3);
    rewardTokens[0] = ETH_ADDRESS;
    rewardTokens[1] = KNC_ADDRESS;
    rewardTokens[2] = USDC_ADDRESS;
    rewardAmounts[0] = 30 ether;
    rewardAmounts[1] = 60 ether;
    rewardAmounts[2] = 3000e6;
  }

  function _verifyUserInfo(
    address account,
    uint256 pId,
    uint256 amount,
    uint256[] memory unclaimedRewards,
    uint256[] memory lastRewardPerShares
  ) public {
    (
      uint256 _amount,
      uint256[] memory _unclaimedRewards,
      uint256[] memory _lastRewardPerShares
    ) = lm.getUserInfo(pId, account);

    assertEq(amount, _amount);
    assertEq(unclaimedRewards, _unclaimedRewards);
    assertEq(lastRewardPerShares, _lastRewardPerShares);
  }

  function _getBalanceOf(address token, address user) public view returns (uint256) {
    if (token == ETH_ADDRESS) return user.balance;
    return IERC20(token).balanceOf(user);
  }

  function _transfer(address token, address to, uint256 amount) public {
    if (token == ETH_ADDRESS) payable(to).transfer(amount);
    else IERC20(token).transfer(to, amount);
  }
}

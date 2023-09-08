// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {GeneratedToken} from 'contracts/periphery/GeneratedToken.sol';
import {IGeneratedToken} from 'contracts/interfaces/periphery/IGeneratedToken.sol';
import {IKSFairLaunchV3} from 'contracts/interfaces/IKSFairLaunchV3.sol';
import {KyberSwapRole} from 'contracts/base/KyberSwapRole.sol';

contract KSFairLaunchV3 is IKSFairLaunchV3, KyberSwapRole, ReentrancyGuard {
  using SafeERC20 for IERC20Metadata;

  uint256 internal constant PRECISION = 1e12;
  uint256 public override poolLength;

  // pool id -> pool info
  mapping(uint256 => PoolInfo) internal pools;

  // pool id -> user address -> user info
  mapping(uint256 => mapping(address => UserInfo)) internal users;

  // pool staked token address -> true then admin can't withdraw
  mapping(address => bool) internal whitelistStakeToken;

  constructor() {}

  receive() external payable {}

  /**
   * @dev Withdraw unused reward. Can only be called by the admin.
   * @param tokenAddress: reward token to withdraw
   * @param amount: amount token to withdraw
   */
  function adminWithdraw(address tokenAddress, uint256 amount) external onlyOwner {
    if (whitelistStakeToken[tokenAddress]) revert NotAllowed();
    _transferToken(tokenAddress, msg.sender, amount);
  }

  /**
   * @dev Add a new lp to the pool. Can only be called by the admin.
   * @param stakeToken: token to be staked to the pool
   * @param startTime: time where the reward starts
   * @param endTime: time where the reward ends
   * @param rewardTokens: reward token
   * @param rewardAmounts: amount of total reward token for the pool for each reward token
   * @param gTokenDatas: name and symbol of generated token
   */
  function addPool(
    address stakeToken,
    uint32 startTime,
    uint32 endTime,
    address[] calldata rewardTokens,
    uint256[] calldata rewardAmounts,
    string[2] calldata gTokenDatas
  ) external onlyOperator {
    if (startTime < block.timestamp || endTime <= startTime) revert InvalidTimes();

    PoolInfo storage pool = pools[poolLength];

    address gToken;
    if (bytes(gTokenDatas[0]).length != 0 && bytes(gTokenDatas[1]).length != 0) {
      gToken = address(new GeneratedToken(gTokenDatas[0], gTokenDatas[1]));
      pool.generatedToken = gToken;
    }

    uint256 multiplierTo;
    for (uint256 i = 0; i < rewardAmounts.length; i++) {
      if (rewardTokens[i] != address(0)) {
        uint8 dToken = IERC20Metadata(rewardTokens[i]).decimals();
        multiplierTo = dToken >= 18 ? 1 : 10 ** (18 - dToken);
      } else {
        multiplierTo = 1;
      }

      pool.poolRewards.push(
        PoolRewardData(
          rewardTokens[i],
          multiplierTo,
          (rewardAmounts[i] * multiplierTo) / (endTime - startTime),
          0
        )
      );
    }
    pool.stakeToken = stakeToken;
    pool.startTime = startTime;
    pool.endTime = endTime;
    pool.lastRewardTime = startTime;
    whitelistStakeToken[stakeToken] = true;
    poolLength++;
    emit AddNewPool(stakeToken, gToken, startTime, endTime);
  }

  /**
   * @dev Renew a pool to start another liquidity mining program
   * @param pId: id of the pool to renew, must be pool that has not started or already ended
   * @param startTime: time where the reward starts
   * @param endTime: time where the reward ends
   * @param rewardAmounts: amount of total reward token for the pool for each reward token
   *   0 if we want to stop the pool from accumulating rewards
   */
  function renewPool(
    uint256 pId,
    uint32 startTime,
    uint32 endTime,
    uint256[] calldata rewardAmounts
  ) external onlyOperator {
    updatePoolRewards(pId);
    // check if pool has not started or already ended
    if (startTime <= block.timestamp || endTime <= startTime) revert InvalidTimes();
    PoolInfo storage pool = pools[pId];
    if (pool.startTime <= block.timestamp && pool.endTime >= block.timestamp) {
      revert InvalidPoolState();
    }
    if (pool.poolRewards.length != rewardAmounts.length) revert InvalidLength();

    pool.startTime = startTime;
    pool.endTime = endTime;
    pool.lastRewardTime = startTime;

    for (uint256 i = 0; i < rewardAmounts.length; i++) {
      pool.poolRewards[i].rewardPerSecond =
        (rewardAmounts[i] * pool.poolRewards[i].multiplier) /
        (endTime - startTime);
    }

    emit RenewPool(pId, startTime, endTime);
  }

  /**
   * @dev Update a pool, allow to change end time, reward per second
   * @param pId: pool id to be renew
   * @param endTime: time where the reward ends
   * @param rewardAmounts: amount of total reward token for the pool for each reward token
   *   0 if we want to stop the pool from accumulating rewards
   */
  function updatePool(
    uint256 pId,
    uint32 endTime,
    uint256[] calldata rewardAmounts
  ) external onlyOperator {
    updatePoolRewards(pId);

    PoolInfo storage pool = pools[pId];

    // should call renew pool if the pool has ended
    if (pool.endTime <= block.timestamp) revert InvalidPoolState();
    if (endTime <= block.timestamp || endTime <= pool.startTime) revert InvalidTimes();
    if (pool.poolRewards.length != rewardAmounts.length) revert InvalidLength();

    pool.endTime = endTime;
    for (uint256 i = 0; i < rewardAmounts.length; i++) {
      pool.poolRewards[i].rewardPerSecond =
        (rewardAmounts[i] * pool.poolRewards[i].multiplier) /
        (endTime - pool.startTime);
    }

    emit UpdatePool(pId, endTime);
  }

  /**
   * @dev Deposit tokens to accumulate rewards
   * @param pId: id of the pool
   * @param amount: amount of stakeToken to be deposited
   * @param shouldHarvest: whether to harvest the reward or not
   */
  function deposit(
    uint256 pId,
    uint256 amount,
    bool shouldHarvest
  ) external override nonReentrant {
    // update pool rewards, user's rewards
    updatePoolRewards(pId);
    _updateUserReward(msg.sender, pId, shouldHarvest);

    PoolInfo storage pool = pools[pId];
    UserInfo storage user = users[pId][msg.sender];

    // collect stakeToken
    IERC20Metadata(pool.stakeToken).safeTransferFrom(msg.sender, address(this), amount);

    address gToken = pool.generatedToken;
    // mint new token for users
    if (gToken != address(0)) {
      IGeneratedToken(gToken).mint(msg.sender, amount);
    }

    // update user staked amount, and total staked amount for the pool
    user.amount += amount;
    pool.totalStake += amount;

    emit Deposit(msg.sender, pId, block.timestamp, amount);
  }

  /**
   * @dev Withdraw token (of the sender) from pool, also harvest rewards
   * @param pId: id of the pool
   * @param amount: amount of stakeToken to withdraw
   */
  function withdraw(uint256 pId, uint256 amount) external override nonReentrant {
    _withdraw(pId, amount);
  }

  /**
   * @dev Withdraw all tokens (of the sender) from pool, also harvest reward
   * @param pId: id of the pool
   */
  function withdrawAll(uint256 pId) external override nonReentrant {
    _withdraw(pId, users[pId][msg.sender].amount);
  }

  /**
   * @notice EMERGENCY USAGE ONLY, USER'S REWARDS WILL BE RESET
   * @dev Emergency withdrawal function to allow withdraw all deposited tokens (of the sender)
   *   and reset all rewards
   * @param pId: id of the pool
   */
  function emergencyWithdraw(uint256 pId) external override nonReentrant {
    PoolInfo storage pool = pools[pId];
    uint256 amount = users[pId][msg.sender].amount;
    delete users[pId][msg.sender];
    pool.totalStake -= amount;
    if (amount > 0) {
      address gToken = pool.generatedToken;
      if (gToken != address(0)) {
        IGeneratedToken(gToken).burn(msg.sender, amount);
      }
      _transferToken(pool.stakeToken, msg.sender, amount);
    }
    emit EmergencyWithdraw(msg.sender, pId, block.timestamp, amount);
  }

  /**
   * @dev Harvest rewards from multiple pools for the sender
   * @param pIds: list pool ids
   */
  function harvestMultiplePools(uint256[] calldata pIds) external override {
    for (uint256 i; i < pIds.length; ) {
      harvest(pIds[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Harvest rewards from a pool for the sender
   * @param pId: id of the pool
   */
  function harvest(uint256 pId) public override {
    updatePoolRewards(pId);
    _updateUserReward(msg.sender, pId, true);
  }

  function updatePoolRewards(uint256 pId) public override {
    if (pId >= poolLength) revert InvalidPool();
    PoolInfo storage pool = pools[pId];

    uint32 lastAccountedTime = _lastAccountedRewardTime(pId);
    uint32 pLastRewardTime = pool.lastRewardTime;
    if (lastAccountedTime <= pLastRewardTime) return;
    uint256 totalStake = pool.totalStake;
    if (totalStake == 0) {
      pool.lastRewardTime = lastAccountedTime;
      return;
    }

    uint256 secondsPassed = lastAccountedTime - pLastRewardTime;
    PoolRewardData[] memory rewardDatas = pool.poolRewards;
    for (uint256 i; i < rewardDatas.length; ) {
      pool.poolRewards[i].accRewardPerShare +=
        (secondsPassed * rewardDatas[i].rewardPerSecond * PRECISION) /
        totalStake;
      unchecked {
        ++i;
      }
    }
    pool.lastRewardTime = lastAccountedTime;
  }

  /**
   * @dev Return full details of a pool
   */
  function getPoolInfo(
    uint256 pId
  )
    external
    view
    override
    returns (
      uint256 totalStake,
      address stakeToken,
      address generatedToken,
      uint32 startTime,
      uint32 endTime,
      uint32 lastRewardTime,
      address[] memory rewardTokens,
      uint256[] memory multipliers,
      uint256[] memory rewardPerSeconds,
      uint256[] memory accRewardPerShares
    )
  {
    PoolInfo storage pool = pools[pId];
    uint256 pRewardsLength = pool.poolRewards.length;

    totalStake = pool.totalStake;
    stakeToken = pool.stakeToken;
    generatedToken = pool.generatedToken;
    startTime = pool.startTime;
    endTime = pool.endTime;
    lastRewardTime = pool.lastRewardTime;

    rewardTokens = new address[](pRewardsLength);
    multipliers = new uint256[](pRewardsLength);
    rewardPerSeconds = new uint256[](pRewardsLength);
    accRewardPerShares = new uint256[](pRewardsLength);

    for (uint256 i = 0; i < rewardTokens.length; i++) {
      rewardTokens[i] = pool.poolRewards[i].rewardToken;
      multipliers[i] = pool.poolRewards[i].multiplier;
      rewardPerSeconds[i] = pool.poolRewards[i].rewardPerSecond;
      accRewardPerShares[i] = pool.poolRewards[i].accRewardPerShare;
    }
  }

  /**
   * @dev Return user's info including deposited amount and reward data
   */
  function getUserInfo(
    uint256 pId,
    address account
  )
    external
    view
    override
    returns (
      uint256 amount,
      uint256[] memory unclaimedRewards,
      uint256[] memory lastRewardPerShares
    )
  {
    UserInfo storage user = users[pId][account];
    amount = user.amount;

    uint256 pRewardsLength = pools[pId].poolRewards.length;
    unclaimedRewards = new uint256[](pRewardsLength);
    lastRewardPerShares = new uint256[](pRewardsLength);
    for (uint256 i = 0; i < pRewardsLength; i++) {
      unclaimedRewards[i] = user.userRewardData[i].unclaimedReward;
      lastRewardPerShares[i] = user.userRewardData[i].lastRewardPerShare;
    }
  }

  /**
   * @dev Get pending rewards of a user from a pool, mostly for front-end
   * @param pId: id of the pool
   * @param userAddr: user to check for pending rewards
   */
  function pendingRewards(
    uint256 pId,
    address userAddr
  ) external view override returns (uint256[] memory rewards) {
    UserInfo storage user = users[pId][userAddr];
    PoolInfo storage pool = pools[pId];
    uint256 pRewardsLength = pool.poolRewards.length;
    rewards = new uint256[](pRewardsLength);

    uint256 totalStake = pool.totalStake;
    uint256 pLastRewardTime = pool.lastRewardTime;
    uint32 lastAccountedTime = _lastAccountedRewardTime(pId);

    for (uint256 i = 0; i < pRewardsLength; i++) {
      uint256 _accRewardPerShare = pool.poolRewards[i].accRewardPerShare;
      if (lastAccountedTime > pLastRewardTime && totalStake != 0) {
        uint256 reward = pool.poolRewards[i].rewardPerSecond *
          (lastAccountedTime - pLastRewardTime);
        _accRewardPerShare += (reward * PRECISION) / totalStake;
      }
      rewards[i] =
        user.userRewardData[i].unclaimedReward +
        (user.amount * (_accRewardPerShare - user.userRewardData[i].lastRewardPerShare)) /
        PRECISION;
    }
  }

  // internal
  function _withdraw(uint256 pId, uint256 amount) internal {
    PoolInfo storage pool = pools[pId];
    UserInfo storage user = users[pId][msg.sender];
    uint256 uAmount = user.amount;
    if (uAmount < amount) revert InsufficientAmount();

    // update pool reward and harvest
    updatePoolRewards(pId);
    _updateUserReward(msg.sender, pId, true);

    user.amount = uAmount - amount;
    pool.totalStake -= amount;

    address gToken = pool.generatedToken;
    if (gToken != address(0)) {
      IGeneratedToken(gToken).burn(msg.sender, amount);
    }
    _transferToken(pool.stakeToken, msg.sender, amount);

    emit Withdraw(msg.sender, pId, block.timestamp, amount);
  }

  function _updateUserReward(address to, uint256 pId, bool shouldHarvest) internal {
    uint256 userAmount = users[pId][to].amount;
    PoolRewardData[] memory pRewards = pools[pId].poolRewards;

    uint256 rTokensLength = pRewards.length;

    if (userAmount == 0) {
      // update user last reward per share to the latest pool reward per share
      // by right if user.amount is 0, user.unclaimedReward should be 0 as well,
      // except when user uses emergencyWithdraw function
      for (uint256 i = 0; i < rTokensLength; i++) {
        users[pId][to].userRewardData[i].lastRewardPerShare = pRewards[i].accRewardPerShare;
      }
      return;
    }

    for (uint256 i = 0; i < rTokensLength; i++) {
      UserRewardData storage rewardData = users[pId][to].userRewardData[i];
      // user's unclaim reward + user's amount * (pool's accRewardPerShare - user's lastRewardPerShare) / precision
      uint256 pendingReward = rewardData.unclaimedReward +
        (userAmount * (pRewards[i].accRewardPerShare - rewardData.lastRewardPerShare)) /
        PRECISION;
      rewardData.unclaimedReward = shouldHarvest ? 0 : pendingReward;
      // update user last reward per share to the latest pool reward per share
      rewardData.lastRewardPerShare = pRewards[i].accRewardPerShare;

      if (shouldHarvest && pendingReward > 0) {
        uint256 amountTransfer = pendingReward / pRewards[i].multiplier;
        _transferToken(pRewards[i].rewardToken, to, amountTransfer);
        emit Harvest(to, pId, pRewards[i].rewardToken, amountTransfer, block.timestamp);
      }
    }
  }

  function _transferToken(address token, address receiver, uint256 amount) internal {
    if (token == address(0)) {
      (bool success, ) = payable(receiver).call{value: amount}('');
      if (!success) revert TransferFail();
    } else {
      IERC20Metadata(token).safeTransfer(receiver, amount);
    }
  }

  function _lastAccountedRewardTime(uint256 pId) internal view returns (uint32 value) {
    value = pools[pId].endTime;
    if (value > block.timestamp) value = uint32(block.timestamp);
  }
}

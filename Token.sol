// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PolygonToken is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    struct StakeInfo {
        uint256 amount;
        uint256 since;
        uint256 claimedRewards;
        uint256 lastClaimTime;
    }
    // token stats
    uint256 public MAX_SUPPLY = 170000000 * 10**18; // 170M Max supply after it, won't mint new token
    uint256 public BASE_APY_RATE = 25000; // 250% APY
    uint256 public constant APY_RATE_DENOMINATOR = 10000;
    uint256 public constant APY_DECREASE_RATE = 500; // 5% decrease per 7 million supply
    uint256 public constant APY_DECREASE_THRESHOLD = 7000000 * 10**18; // amount token to decrease apy
    uint256 public constant FORFEIT_TIME = 730 days; // dawg this simple
    
    uint256 public totalStaked;
    uint256 public totalBurned;
    uint256 public stakerCount;
    uint256 public totalMinted;
    
    mapping(address => StakeInfo) public stakeInfos;
    
    event Staked(address indexed user, uint256 amount, uint256 totalStaked);
    event RewardClaimed(address indexed user, uint256 reward);
    event TokensBurned(address indexed user, uint256 amount, uint256 totalBurned);
    event StakeForfeit(address indexed user, uint256 amount, uint256 unclaimedRewards);
    event MaxSupplyReached();
    // token name, symbol, decimals, supply
    constructor() ERC20("Pvicsh", "PIH") Ownable(msg.sender) {
        uint256 initialSupply = 1700000 * 10**decimals();
        _mint(msg.sender, initialSupply);
        totalMinted = initialSupply;
    }
    
    function calculateRewards(address _staker) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakeInfos[_staker];
        if (stakeInfo.amount == 0) return 0;
        
        if (block.timestamp - stakeInfo.lastClaimTime >= FORFEIT_TIME) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - stakeInfo.since;
        
        uint256 currentAPY = getCurrentAPY();
        uint256 rewardRate = (currentAPY * 1e18) / (365 * 86400 * APY_RATE_DENOMINATOR);
        uint256 rewards = (stakeInfo.amount * timeElapsed * rewardRate) / 1e18;
        
        return rewards;
    }
    
    function getCurrentAPY() public view returns (uint256) {
        // Calculate APY reduction based on total minted tokens
        uint256 supplyGroups = totalMinted / APY_DECREASE_THRESHOLD;
        uint256 apyReduction = supplyGroups * APY_DECREASE_RATE;
        
        if (apyReduction >= BASE_APY_RATE) {
            return 0;
        }
        
        return BASE_APY_RATE - apyReduction;
    }
    
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        bool isNewStaker = stakeInfo.amount == 0;
        
        if (stakeInfo.amount > 0) {
            uint256 pendingRewards = calculateRewards(msg.sender);
            stakeInfo.claimedRewards += pendingRewards;
        }
        
        stakeInfo.amount += _amount;
        stakeInfo.since = block.timestamp;
        stakeInfo.lastClaimTime = block.timestamp;
        
        if (isNewStaker) {
            stakerCount++;
        }
        
        totalStaked += _amount;
        totalBurned += _amount;
        
        _burn(msg.sender, _amount);
        
        emit Staked(msg.sender, _amount, stakeInfo.amount);
        emit TokensBurned(msg.sender, _amount, totalBurned);
    }
    
    function addStake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(stakeInfos[msg.sender].amount > 0, "Must have existing stake");
        
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        
        uint256 pendingRewards = calculateRewards(msg.sender);
        stakeInfo.claimedRewards += pendingRewards;
        
        stakeInfo.amount += _amount;
        stakeInfo.since = block.timestamp;
        stakeInfo.lastClaimTime = block.timestamp;
        
        totalStaked += _amount;
        totalBurned += _amount;
        
        _burn(msg.sender, _amount);
        
        emit Staked(msg.sender, _amount, stakeInfo.amount);
        emit TokensBurned(msg.sender, _amount, totalBurned);
    }
    
    function claimRewards() external nonReentrant {
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        require(stakeInfo.amount > 0, "No tokens staked");
        
        uint256 rewards = calculateRewards(msg.sender);
        
        stakeInfo.since = block.timestamp;
        stakeInfo.lastClaimTime = block.timestamp;
        stakeInfo.claimedRewards += rewards;
        
        if (rewards > 0) {
            // Check if we would exceed MAX_SUPPLY
            uint256 currentSupply = totalSupply();
            if (currentSupply + rewards > MAX_SUPPLY) {
                // Hanya mint sampai batas MAX_SUPPLY
                uint256 remainingSupply = MAX_SUPPLY > currentSupply ? MAX_SUPPLY - currentSupply : 0;
                
                if (remainingSupply > 0) {
                    _mint(msg.sender, remainingSupply);
                    totalMinted += remainingSupply;
                    emit RewardClaimed(msg.sender, remainingSupply);
                }
                
                emit MaxSupplyReached();
            } else {
                _mint(msg.sender, rewards);
                totalMinted += rewards;
                emit RewardClaimed(msg.sender, rewards);
            }
        }
    }
    
    // Split getStakeInfo for no error
    function getStakeInfo(address _staker) external view returns (
        uint256 amount,
        uint256 since,
        uint256 claimedRewards,
        uint256 pendingRewards
    ) {
        StakeInfo memory stakeInfo = stakeInfos[_staker];
        
        return (
            stakeInfo.amount,
            stakeInfo.since,
            stakeInfo.claimedRewards,
            calculateRewards(_staker)
        );
    }
    
    function getStakeStatus(address _staker) external view returns (
        uint256 totalBurnedTokens,
        uint256 lastClaimTime,
        bool isForfeitable,
        uint256 timeUntilForfeit,
        uint256 currentAPY
    ) {
        StakeInfo memory stakeInfo = stakeInfos[_staker];
        bool forfeitable = false;
        uint256 remainingTime = 0;
        
        if (stakeInfo.amount > 0) {
            if (block.timestamp >= stakeInfo.lastClaimTime + FORFEIT_TIME) {
                forfeitable = true;
                remainingTime = 0;
            } else {
                remainingTime = (stakeInfo.lastClaimTime + FORFEIT_TIME) - block.timestamp;
            }
        }
        
        return (
            totalBurned,
            stakeInfo.lastClaimTime,
            forfeitable,
            remainingTime,
            getCurrentAPY()
        );
    }
    
    function getAPYPercentage() external view returns (uint256) {
        return getCurrentAPY() / 100;
    }
    
    function getMaxSupply() external view returns (uint256) {
        return MAX_SUPPLY;
    }
    
    function getRemainingSupply() external view returns (uint256) {
        uint256 currentSupply = totalSupply();
        if (currentSupply >= MAX_SUPPLY) {
            return 0;
        }
        return MAX_SUPPLY - currentSupply;
    }
    
    function getTotalStakers() external view returns (uint256) {
        return stakerCount;
    }
    
    function forfeitInactiveStake(address _staker) external {
        StakeInfo storage stakeInfo = stakeInfos[_staker];
        require(stakeInfo.amount > 0, "No stake to forfeit");
        require(block.timestamp - stakeInfo.lastClaimTime >= FORFEIT_TIME, "Stake not eligible for forfeiture yet");
        
        uint256 stakedAmount = stakeInfo.amount;
        uint256 unclaimedRewards = calculateRewards(_staker);
        
        totalStaked -= stakedAmount;
        stakerCount--;
        
        delete stakeInfos[_staker];
        
        emit StakeForfeit(_staker, stakedAmount, unclaimedRewards);
    }
}
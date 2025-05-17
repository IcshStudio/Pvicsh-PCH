Sorry if this README bad, because i bad at this, you can do anything with this Solidity token code you could improve
Or just take the code

For Deploy you can use Remix or Hardhat, but i recommend Remix because it more easy

Alright so what is Pvicsh? $PIH is a deflationary staking token on Polygon with built-in burn mechanism and dynamic APY system and
Forfeit system that make user Cannot claim their staking token after 2 year no claim data of their wallet.
---------------------
How does ts works?

Pvicsh (PIH) combines staking rewards with a unique deflationary mechanism. 
When users stake tokens, they're burned from circulation while still earning rewards based on the current APY rate.
---------------------
If you lazy to read here the simple feature $PIH has

Deflationary Model: Staking burns tokens from circulation
Dynamic Rewards: APY starts at 250% and decreases as supply grows
Hard Cap: Maximum supply of 170 million tokens
Stake Management: Users can add to their stake or claim rewards
Inactivity Protection: Stakes inactive for 2 years can be forfeit
---------------------
Simple Way to teach how the stake works

stake(amount): Burn tokens and start earning rewards
addStake(amount): Add more tokens to existing stake
claimRewards(): Mint and collect earned rewards
---------------------
Info Functions

calculateRewards(address): View pending rewards
getCurrentAPY(): Check current APY rate
getStakeInfo(address): View stake details
getStakeStatus(address): Check stake status
---------------------
Economics

Initial Supply: 1.7 million PIH
Max Supply: 170 million PIH
Base APY: 250% (decreases by 5% per 7 million tokens minted)
---------------------
Security
Built with OpenZeppelin contracts for maximum security, including:
---------------------
ReentrancyGuard
ERC20Burnable
Ownable
---------------------

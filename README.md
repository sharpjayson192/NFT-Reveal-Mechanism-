# 🎭 NFT Reveal Mechanism

A Clarity smart contract implementing a commit-reveal scheme for fair NFT distribution on the Stacks blockchain.

## 🚀 Features

- 🔐 **Commit-Reveal Pattern**: Fair distribution mechanism preventing front-running
- 🎨 **Dynamic NFT Generation**: Metadata generated based on revealed values
- 📅 **Time-Based Phases**: Structured commit, reveal, and mint phases
- 🛡️ **Secure Randomness**: Uses SHA256 hashing for commitment verification
- 🎯 **Rarity System**: 5 tiers of NFT rarity (Common, Rare, Epic, Legendary, Mythic)
- 🤝 **Referral & Rewards**: Viral growth mechanics with token rewards for bringing new users
- 🏦 **Staking & Yield Farming**: Time-locked staking pools with yield generation for reward tokens
- 🎰 **Provably Fair Lottery**: Decentralized lottery rounds with transparent winner selection

## 🔄 How It Works

### Phase 1: Commit 💭
Users submit a hash commitment of their chosen value + nonce without revealing the actual value.

### Phase 2: Reveal 🎪
Users reveal their original value and nonce, which must match their commitment hash.

### Phase 3: Mint 🎨
Users mint their NFT with metadata determined by their revealed value.

## 🛠️ Usage

### Initialize the Contract
```bash
# Set phase durations (in blocks)
(contract-call? .nft-reveal-mechanism initialize-phases u100 u50 u200)
```

### Commit Phase
```bash
# Standard commit
(contract-call? .nft-reveal-mechanism commit 0x...)

# Commit with referral (earn rewards for referrer)
(contract-call? .nft-reveal-mechanism commit-with-referral 0x... 'ST1REFERRER...)
```

### Reveal Phase
```bash
# Reveal your original value and nonce
(contract-call? .nft-reveal-mechanism reveal u42 u123)
```

### Mint Phase
```bash
# Mint your NFT based on revealed value
(contract-call? .nft-reveal-mechanism mint-nft)
```

## 🤝 Referral System

### Earn Rewards by Referring
```bash
# When new users commit with your address as referrer, you earn 100 reward tokens
# They can commit using:
(contract-call? .nft-reveal-mechanism commit-with-referral 0x... tx-sender)
```

### Claim & Use Rewards
```bash
# Referred users can claim 50 bonus tokens during mint phase
(contract-call? .nft-reveal-mechanism claim-referral-bonus)

# Check reward balance
(contract-call? .nft-reveal-mechanism get-reward-balance tx-sender)

# Spend rewards (implementation-specific usage)
(contract-call? .nft-reveal-mechanism spend-rewards u25)

# Transfer rewards to another user
(contract-call? .nft-reveal-mechanism transfer-rewards 'ST1RECIPIENT... u50)
```

## 🏦 Staking & Yield Farming

### Create Staking Pools (Owner Only)
```bash
# Create a staking pool: name, yield-rate (basis points), min-stake, lock-period (blocks)
(contract-call? .nft-reveal-mechanism create-staking-pool "High Yield" u500 u100 u1000)
```

### Stake & Earn Yields
```bash
# Stake tokens in a pool
(contract-call? .nft-reveal-mechanism stake-tokens u1 u500)

# Check staking info and current yields
(contract-call? .nft-reveal-mechanism get-stake-info tx-sender)

# Unstake after lock period (receive principal + yields)
(contract-call? .nft-reveal-mechanism unstake-tokens)

# Emergency unstake (10% penalty)
(contract-call? .nft-reveal-mechanism emergency-unstake)
```

### Pool Analytics
```bash
# Get pool information
(contract-call? .nft-reveal-mechanism get-pool-info u1)

# Get overall staking overview
(contract-call? .nft-reveal-mechanism get-staking-overview)
```

## 🎰 Lottery System

### Start Lottery Rounds (Owner Only)
```bash
# Start new lottery: ticket-price, max-tickets, duration (blocks)
(contract-call? .nft-reveal-mechanism start-lottery u10 u100 u1440)
```

### Participate & Win
```bash
# Buy lottery tickets (up to 20 per transaction)
(contract-call? .nft-reveal-mechanism buy-lottery-tickets u1 u5)

# Check your tickets
(contract-call? .nft-reveal-mechanism get-user-lottery-tickets u1 tx-sender)

# Check current lottery status
(contract-call? .nft-reveal-mechanism get-current-lottery)
```

### Drawing & Prize Claiming
```bash
# Draw winner after lottery ends (Owner only)
(contract-call? .nft-reveal-mechanism draw-lottery-winner u1 u12345)

# Claim prize if you won
(contract-call? .nft-reveal-mechanism claim-lottery-prize u1)

# View your lottery statistics
(contract-call? .nft-reveal-mechanism get-lottery-stats tx-sender)
```

## 📊 Contract Functions

### Public Functions
- `initialize-phases` - Set up commit/reveal/mint durations
- `commit` - Submit commitment hash
- `commit-with-referral` - Submit commitment with referrer for rewards
- `reveal` - Reveal value and nonce
- `mint-nft` - Mint NFT after successful reveal
- `claim-referral-bonus` - Claim bonus rewards for being referred
- `spend-rewards` - Spend accumulated reward tokens
- `transfer-rewards` - Transfer rewards to another user
- `create-staking-pool` - Create new staking pool with yield parameters
- `stake-tokens` - Stake reward tokens in a pool for yields
- `unstake-tokens` - Unstake after lock period with earned yields
- `emergency-unstake` - Early unstake with 10% penalty
- `start-lottery` - Launch new lottery round with parameters
- `buy-lottery-tickets` - Purchase tickets for active lottery
- `draw-lottery-winner` - Select winner after round ends
- `claim-lottery-prize` - Winners claim their prize pool
- `transfer` - Transfer NFT ownership
- `approve` - Approve spender for token
- `transfer-from` - Transfer from approved address

### Read-Only Functions
- `get-current-phase` - Get current contract phase
- `get-user-commitment` - Check user's commitment
- `get-user-reveal` - Check user's reveal data
- `get-user-token` - Get user's minted token ID
- `get-token-metadata` - Get NFT metadata
- `get-phase-info` - Get all phase timing info
- `get-referral-info` - Get user's referral statistics and rewards
- `get-reward-balance` - Check user's reward token balance
- `get-stake-info` - Get user's staking details and current yields
- `get-pool-info` - Get staking pool details and statistics
- `get-staking-overview` - Get global staking statistics
- `get-lottery-round` - Get lottery round details by ID
- `get-user-lottery-tickets` - Get user's tickets for a round
- `get-lottery-stats` - Get user's lottery participation statistics
- `get-current-lottery` - Get active lottery information
- `get-lottery-overview` - Get global lottery statistics

## 🎮 Testing

### Local Testing
```bash
# Run Clarinet tests
clarinet test

# Check contract in console
clarinet console
```

### Example Test Flow
1. Deploy contract
2. Initialize phases with test durations
3. Commit with referral to earn rewards
4. Advance to reveal phase
5. Reveal with matching value/nonce
6. Advance to mint phase
7. Mint NFT and verify metadata
8. Claim referral bonuses and transfer rewards
9. Create staking pools and stake tokens for yields
10. Start lottery rounds and participate for prize pools

## 🏗️ Project Structure

```
├── contracts/
│   └── nft-reveal-mechanism.clar    # Main contract
├── tests/
│   └── nft-reveal-mechanism_test.ts # Test suite
├── Clarinet.toml                    # Clarinet config
└── README.md                        # This file
```

## 🔧 Configuration

Edit `Clarinet.toml` to configure:
- Contract deployment settings
- Network configurations
- Testing parameters

## 🎯 Rarity Distribution

| Value % 5 | Rarity | Description |
|-----------|--------|-------------|
| 0 | Common | Basic traits |
| 1 | Rare | Special traits |
| 2 | Epic | Unique traits |
| 3 | Legendary | Extraordinary traits |
| 4 | Mythic | Divine traits |

## 🛡️ Security Features

- ✅ Owner-only initialization
- ✅ Phase-based access control
- ✅ Commitment verification
- ✅ Duplicate prevention
- ✅ Authorization checks
- ✅ Self-referral prevention
- ✅ Reward balance validation
- ✅ Staking pool management
- ✅ Time-lock enforcement
- ✅ Emergency unstake penalties
- ✅ Lottery round lifecycle management
- ✅ Transparent winner selection
- ✅ Prize pool distribution

## 📈 Error Codes

- `u100` - Owner only
- `u101` - Not found
- `u102` - Already exists
- `u103` - Invalid phase
- `u104` - Already committed
- `u105` - Not committed
- `u106` - Invalid reveal
- `u107` - Already revealed
- `u108` - Already minted
- `u109` - Invalid token
- `u110` - Unauthorized

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

Built with ❤️ using Clarity and Clarinet on Stacks blockchain

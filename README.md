# 🎭 NFT Reveal Mechanism

A Clarity smart contract implementing a commit-reveal scheme for fair NFT distribution on the Stacks blockchain.

## 🚀 Features

- 🔐 **Commit-Reveal Pattern**: Fair distribution mechanism preventing front-running
- 🎨 **Dynamic NFT Generation**: Metadata generated based on revealed values
- 📅 **Time-Based Phases**: Structured commit, reveal, and mint phases
- 🛡️ **Secure Randomness**: Uses SHA256 hashing for commitment verification
- 🎯 **Rarity System**: 5 tiers of NFT rarity (Common, Rare, Epic, Legendary, Mythic)

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
# Generate commitment hash: sha256(value + nonce)
# Example: sha256("42" + "secret123")
(contract-call? .nft-reveal-mechanism commit 0x...)
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

## 📊 Contract Functions

### Public Functions
- `initialize-phases` - Set up commit/reveal/mint durations
- `commit` - Submit commitment hash
- `reveal` - Reveal value and nonce
- `mint-nft` - Mint NFT after successful reveal
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
3. Commit with hash
4. Advance to reveal phase
5. Reveal with matching value/nonce
6. Advance to mint phase
7. Mint NFT and verify metadata

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

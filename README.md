# Foundry CCIP Rebase Token

**⚠️ This is an educational project - not audited, use at your own risk**

## Table of Contents

- [Foundry CCIP Rebase Token](#foundry-ccip-rebase-token)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
    - [Key Features](#key-features)
    - [Architecture](#architecture)
    - [How It Works](#how-it-works)
      - [**Interest Calculation Formula**](#interest-calculation-formula)
      - [**Step-by-Step: User Deposits 1 ETH**](#step-by-step-user-deposits-1-eth)
      - [**Example: Interest Accrual Over Time**](#example-interest-accrual-over-time)
      - [**Key Behaviors**](#key-behaviors)
      - [**Interest Rate Dynamics**](#interest-rate-dynamics)
      - [**Vault Reserve Management**](#vault-reserve-management)
      - [**Cross-Chain Bridging**](#cross-chain-bridging)
  - [Getting Started](#getting-started)
    - [Requirements](#requirements)
    - [Quickstart](#quickstart)
    - [Environment Setup](#environment-setup)
  - [Usage](#usage)
    - [Build](#build)
    - [Testing](#testing)
    - [Test Coverage](#test-coverage)
    - [Deploy Locally](#deploy-locally)
    - [Interact with Contract](#interact-with-contract)
  - [Deployment](#deployment)
    - [Deploy to Testnet](#deploy-to-testnet)
    - [Verify Contract](#verify-contract)
    - [Deployment Addresses](#deployment-addresses)
  - [Security](#security)
    - [Audit Status](#audit-status)
    - [Access Control (Roles \& Permissions)](#access-control-roles--permissions)
    - [Known Limitations](#known-limitations)
  - [Gas Optimization](#gas-optimization)
  - [Contributing](#contributing)
  - [License](#license)

## About

This project implements a cross-chain rebase token (RBT) protocol that incentivizes early vault deposits through a dynamic interest accrual mechanism. Users deposit ETH into a vault and receive rebase tokens that automatically accumulate interest over time, with each user having their own personal interest rate locked at their deposit time.

### Key Features

- **Dynamic Rebase Mechanism**: Token balance grows automatically with time based on personal interest rates
- **Cross-Chain Support**: Seamlessly bridge rebase tokens across chains using Chainlink CCIP
- **Interest Rate Incentives**: Early depositors receive higher interest rates; global rates can only decrease
- **Personal Interest Rates**: Each user's rate is a snapshot of the global rate at their deposit time
- **Access Control**: Role-based permissions for minting/burning and owner-controlled operations
- **Vault Integration**: Secure ETH deposit mechanism with automatic RBT minting on deposit and burning on withdrawal

**Tech Stack:**
- Solidity ^0.8.24
- Foundry (Forge/Cast)
- Chainlink CCIP (Cross-Chain Messaging Protocol)
- OpenZeppelin Contracts (ERC20, AccessControl, Ownable)

### Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                              Users/EOAs                                             │
└──────────────────────────────────────────────────────────┬───────────────────────┬──────────────────────────────────┘
                   │                              │
             deposit(ETH)                  redeem(RBT)
                   │                              │
                   ▼                              ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                             VAULT CONTRACT                                           │
│  • Receives ETH deposits                                                            │
│  • Calls mint() on RebaseToken                                                     │
│  • Holds ETH reserves for redemptions                                              │
└──────────────────────────────────────────────┬───────────────────────────────────────┬───────────────────────────────────┘
                   │                              │
            mint(user, amount)             burn(user, amount)
                   │                              │
                   ▼                              ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                        REBASE TOKEN CONTRACT                                         │
│  ┌────────────────────────────────────────────────────────────────────────────────┐          │
│  │  • ERC20 Token with dynamic balanceOf()                                        │          │
│  │  • Personal interest rates per user (locked at deposit)                        │          │
│  │  • Global interest rate (owner controlled, decreases only)                     │          │
│  │  • Access Control (MINT_AND_BURN_ROLE)                                        │          │
│  │  • Interest accrual: balance * (1 + rate * timeElapsed)                       │          │
│  └────────────────────────────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────┬────────────────────────────┬────────────────────────────────────┘
                   │                              │
            burn() or transfer()            cross-chain bridge
                   │                              │
                   └──────────────────┬───────────┘
                                      │
                        ┌─────────────┴──────────────┐
                        │  REBASE TOKEN POOL         │
                        │  (Chainlink CCIP)          │
                        │  • lockOrBurn() on src     │
                        │  • mint() on destination   │
                        │  • Preserves interest      │
                        └─────────────┬──────────────┘
                                      │
                        ┌─────────────┴──────────────┐
                        │  Chainlink CCIP Router     │
                        │  • Cross-chain messaging   │
                        │  • Multi-chain coord.      │
                        └────────────────────────────┘
```

**Repository Structure:**
```
foundry-ccip-rebase-token/
├── src/
│   ├── RebaseToken.sol           # Core ERC20 with rebasing mechanics
│   ├── RebaseTokenPool.sol       # Chainlink CCIP token pool for bridging
│   ├── Vault.sol                 # ETH deposit/withdrawal vault
│   └── interfaces/
│       └── IRebaseToken.sol       # Interface for RebaseToken
├── script/
│   ├── DeployRBT.s.sol           # Deployment script for all contracts
│   └── Interactions.s.sol        # Cross-chain interaction scripts
├── test/
│   ├── unit/
│   │   └── RebaseTokenUnitTest.t.sol      # Unit tests for token logic
│   ├── integration/
│   │   ├── DeployRBTTest.t.sol            # Deployment integration tests
│   │   ├── VaultTest.t.sol                # Vault functionality tests
│   │   └── CrossChainTest.t.sol           # CCIP bridging tests
│   ├── fuzz/
│   │   └── RebaseTokenFuzzTest.t.sol      # Fuzz testing for edge cases
│   └── mocks/
│       └── InvalidReceiverMock.sol        # Mock contracts for testing
├── lib/                           # Dependencies
│   ├── chainlink-local/           # Chainlink CCIP local simulator
│   ├── forge-std/                 # Foundry standard library
│   └── openzeppelin-contracts/    # OpenZeppelin ERC20, AccessControl, etc.
├── foundry.toml                   # Foundry configuration
├── Makefile                       # Development commands
├── package.json                   # Node dependencies
├── README.md                      # This file
└── NOTES.md                       # Project notes and known issues
```

### How It Works

The Rebase Token protocol enables users to earn interest on their deposits through a dynamic interest accrual mechanism. Here's a detailed walkthrough of how it operates:

#### **Interest Calculation Formula**

The key formula governing interest accrual is derived from the contract's `balanceOf()` and `_calculateUserAccumulatedInterestSinceLastUpdate()` functions:

$$\text{Current Balance} = \text{Principal} \times \frac{10^{18} + \text{userInterestRate} \times \text{timeElapsed}}{10^{18}}$$

Or equivalently:

$$\text{Current Balance} = \text{Principal} \times \left(1 + \frac{\text{userInterestRate} \times \text{timeElapsed}}{10^{18}}\right)$$

Where:
- **Principal**: The amount of RBT tokens you currently hold (stored on-chain)
- **userInterestRate**: Your personal interest rate (locked at deposit time), expressed in wei per second
- **timeElapsed**: Time in seconds since your last update (mint, burn, or transfer)
- **Precision factor** ($10^{18}$): Used to handle decimal precision in Solidity arithmetic

#### **Step-by-Step: User Deposits 1 ETH**

Let's walk through what happens when a user deposits 1 ETH:

**1. User calls `deposit()` on the Vault:**
```
User sends: 1 ETH
Vault receives: 1 ETH in its ETH reserve
```

**2. Vault calls `mint()` on RebaseToken:**
```
Vault mints: 1.0 RBT to the user
User's principal balance: 1.0 RBT
```

**3. Interest rate is set:**
```
Global interest rate at time of deposit: 5e10 wei/second (0.00000005 per second)
User's personal interest rate: 5e10 (locked in for this user)
Last updated timestamp: block.timestamp
```

**4. No balance change yet:**
```
balanceOf(user) = 1.0 RBT (principal × multiplier where multiplier = 1 initially)
```

#### **Example: Interest Accrual Over Time**

Now let's see how interest grows after the initial deposit of 1 ETH at rate 5e10 (wei per second):

| Time Elapsed | Multiplier Calculation | Multiplier | RBT Balance |
|--------------|------------------------|------------|------------|
| 0 seconds | `(1e18 + 5e10 × 0) / 1e18` | `1.000000` | **1.000000** RBT |
| 1 day (86,400s) | `(1e18 + 5e10 × 86400) / 1e18` | `1.00432` | **1.00432** RBT |
| 7 days (604,800s) | `(1e18 + 5e10 × 604800) / 1e18` | `1.03024` | **1.03024** RBT |
| 30 days (2,592,000s) | `(1e18 + 5e10 × 2592000) / 1e18` | `1.1296` | **1.1296** RBT |
| 365 days (31,536,000s) | `(1e18 + 5e10 × 31536000) / 1e18` | `2.5768` | **2.5768** RBT |

**Interpretation:**
- After 1 day: You've earned 0.00432 RBT in interest (~0.432% daily gain)
- After 7 days: You've earned 0.03024 RBT (~3.024% gain over the week)
- After 30 days: You've earned 0.1296 RBT (~12.96% monthly gain)
- After 1 year: You've earned 1.5768 RBT (~157.68% annual gain / ~157.68% APY)
- Your principal still remains 1.0 RBT (used in calculations until interest is minted)

#### **Key Behaviors**

**Automatic Interest Minting:**
When you perform any action (mint, burn, transfer), the protocol:
1. Calculates accrued interest since last update
2. Mints that interest as new RBT tokens to your account
3. Updates your `s_userUpdatedAt` timestamp to now
4. Your principal balance increases (now includes the accrued interest)

**Example - After 30 days, you transfer your tokens:**
```
Before transfer:
  - principalBalanceOf(user) = 1.0 RBT
  - balanceOf(user) = 1.1296 RBT (includes interest)
    [Calculated as: (1e18 × (1e18 + 5e10 × 2592000)) / 1e18]

Transfer call triggers _mintAccruedInterest():
  - Mints: 0.1296 RBT to user
  - Updates s_userUpdatedAt to current block.timestamp
  
After transfer:
  - principalBalanceOf(user) = 1.1296 RBT (increased!)
  - balanceOf(user) = 1.1296 RBT (no un-minted interest yet)
  - Next interest accrual begins from this new principal base
```

#### **Interest Rate Dynamics**

**Personal Rate (Locked at Deposit):**
- Set to the global interest rate when you deposit
- Never changes for your account unless you deposit again
- Early depositors lock in higher rates

**Global Rate (Owner Controlled):**
- Can only decrease over time (never increase)
- New deposits use the current global rate
- If you deposit again later at a lower rate, your personal rate updates down

**Example Timeline:**
```
Day 1: Global rate = 5e10, User A deposits (locked at 5e10)
Day 30: Global rate decreases to 3e10, User A deposits more (personal rate now 3e10)
Day 60: User B deposits (locked at 3e10, lower than User A's first deposit)
```

#### **Vault Reserve Management**

The Vault contract holds ETH and mints/burns RBT accordingly:
- Deposit: User sends ETH → Vault receives ETH → RBT is minted to user
- Redeem: User burns RBT → Vault sends ETH to user

**Important:** The Vault must always have sufficient ETH to cover all redemptions. If users heavily exploit the compounding-via-transfer mechanism, actual interest can exceed linear projections.

#### **Cross-Chain Bridging**

When you bridge RBT tokens to another chain:
1. RebaseTokenPool calls `lockOrBurn()` to burn your tokens on source chain
2. Your current interest rate is encoded and sent via Chainlink CCIP
3. On the destination chain, tokens are minted with your interest rate preserved
4. Your balance continues to accrue interest at the same personal rate

## Getting Started

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - Verify installation: `git --version`
- [foundry](https://getfoundry.sh/)
  - Verify installation: `forge --version`

### Quickstart

```bash
git clone https://github.com/0xGearhart/foundry-ccip-rebase-token
cd foundry-ccip-rebase-token
make install
forge build
```

### Environment Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your `.env` file:**
   ```bash
   ETH_MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
   ETH_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
   ARB_MAINNET_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/your-api-key
   ARB_SEPOLIA_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/your-api-key
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   DEFAULT_KEY_ADDRESS=public_address_of_your_encrypted_private_key_here
   ```

3. **Get testnet ETH & LINK:**
   - Sepolia Faucet: [cloud.google.com/application/web3/faucet/ethereum/sepolia](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)
   - Link testnet faucets: [faucets.chain.link/](https://faucets.chain.link/)

**⚠️ Security Warning:**
- Never commit your `.env` file
- Never use your mainnet private key for testing
- Use a separate wallet with only testnet funds

## Usage

### Build

Compile the contracts:

```bash
forge build
```

### Testing

Run the entire test suite:

```bash
forge test
```

Run tests with verbosity levels (more v's = more detail):

```bash
forge test -vvv  # High verbosity
forge test -vvvv # Very high verbosity
```

Run specific test contract:

```bash
forge test --mc RebaseTokenUnitTest
```

Run specific test function:

```bash
forge test --mt testMintAccruedInterest
```

Run specific tests in path:

```bash
forge test --match-path test/integration/
```

### Test Coverage

Generate coverage report:

```bash
forge coverage
```

### Deploy Locally

Start a local Anvil node:

```bash
make anvil
```

Deploy to local node (in another terminal):

```bash
make deploy
```

### Interact with Contract

**Deposit ETH to mint RBT tokens:**

```bash
cast send <VAULT_ADDRESS> "deposit()" --value 1ether --rpc-url $SEPOLIA_RPC_URL --account defaultKey
```

**Check RBT balance (includes accrued interest):**

```bash
cast call <RBT_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

**Check principal balance (without interest):**

```bash
cast call <RBT_ADDRESS> "principalBalanceOf(address)" <YOUR_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

**Check your personal interest rate:**

```bash
cast call <RBT_ADDRESS> "getUserInterestRate(address)" <YOUR_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

**Check global interest rate:**

```bash
cast call <RBT_ADDRESS> "getGlobalInterestRate()" --rpc-url $SEPOLIA_RPC_URL
```

**Redeem RBT tokens to withdraw ETH:**

```bash
cast send <VAULT_ADDRESS> "redeem(uint256)" 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --account defaultKey
```

**Using Makefile shortcuts:**

Be sure to edit make file with your specific contract addresses, amounts, chain selectors, and gas limits.

```bash
# Deposit and mint RBT
make depositToVaultAndMintRbt ARGS="--network eth sepolia"

# Bridge tokens across chains
make bridgeTokensFromSource ARGS="--network eth sepolia"
```

## Deployment

### Deploy to Testnet

Deploy to Ethereum Sepolia (source chain):

Be sure to answer "y" when prompted to also deploy vault contract on source chain ONLY. Do not deploy vault on destination chain, only source chain needs a vault contract.

```bash
make deploy ARGS="--network eth sepolia"
y
```

Deploy to Arbitrum Sepolia (destination chain):

Be sure to answer "n" when prompted to skip deploying vault contract on destination chain. Do not deploy vault on destination chain, only source chain needs a vault contract.

```bash
make deploy ARGS="--network eth sepolia"
n
```

Or using forge directly:

```bash
forge script script/DeployRBT.s.sol:DeployRBT --sig "run(bool)" <DEPLOY_VAULT_FLAG> --rpc-url $ETH_SEPOLIA_RPC_URL --account <YOUR_ENCRYPTED_KEY_NAME> --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

**Note:** The `run(bool)` signature determines whether to deploy the Vault contract. Pass `true` to deploy Vault, `false` to skip.

### Verify Contract

If automatic verification fails:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/RebaseToken.sol:RebaseToken --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY
```

### Deployment Addresses

| Network | Contract | Address | Explorer |
|---------|----------|---------|----------|
| Sepolia | Vault | `0x12639d86f599921c1b54d502834a55b25AEC5D5e` | [View](https://sepolia.etherscan.io/address/0x12639d86f599921c1b54d502834a55b25AEC5D5e) |
| Sepolia | Rebase Token (RBT) | `0x98f2e36a043D6828F856a7008Aa5502c10974e51` | [View](https://sepolia.etherscan.io/address/0x98f2e36a043D6828F856a7008Aa5502c10974e51) |
| Sepolia | RBT Token Pool | `0x7099bF52dBF2f9BDa10a5C7AAae3050886271a4d` | [View](https://sepolia.etherscan.io/address/0x7099bF52dBF2f9BDa10a5C7AAae3050886271a4d) |
| Arbitrum Sepolia | Rebase Token (RBT) | `0x3303128056E8B7459C403277AC88468992058941` | [View](https://sepolia.arbiscan.io/address/0x3303128056E8B7459C403277AC88468992058941) |
| Arbitrum Sepolia | RBT Token Pool | `0xE24BcCBFC48878ea59146E98cfef871d920891Fd` | [View](https://sepolia.arbiscan.io/address/0xE24BcCBFC48878ea59146E98cfef871d920891Fd) |

**Mainnet Deployment Status:** Not yet deployed to mainnet. Use testnet addresses for testing.

## Security

### Audit Status

⚠️ **This contract has not been audited.** Use at your own risk.

For production use, consider:
- Professional security audit from established firm
- Bug bounty program on platforms like Immunefi
- Gradual rollout with monitoring and rate limits
- Formal verification of critical math functions

### Access Control (Roles & Permissions)

The protocol implements OpenZeppelin's `AccessControl` and `Ownable` for fine-grained permission management:

**Roles:**
- **`MINT_AND_BURN_ROLE`**: Critical role for minting and burning RBT tokens
  - Granted to `Vault` contract (for deposit/withdrawal operations)
  - Granted to `RebaseTokenPool` contract (for cross-chain operations)
  - Only the owner can grant this role

**Owner Permissions:**
- `setInterestRate()`: Decrease the global interest rate (can only decrease, never increase)
- `grantMintAndBurnRole()`: Grant minting/burning permissions to authorized contracts

**Access Control Vulnerabilities & Mitigations:**
- ⚠️ **Risk**: Owner could grant `MINT_AND_BURN_ROLE` to malicious actor
  - **Mitigation**: Use multi-sig wallet for owner role in production
- ⚠️ **Risk**: Owner control of interest rate changes
  - **Mitigation**: Decentralize rate changes through governance in production

### Known Limitations

1. **`totalSupply()` Accuracy**: The `totalSupply()` function returns only the principal balance without accrued interest to prevent denial-of-service attacks from looping through all users.

2. **Owner Privilege**: The contract owner can grant the `MINT_AND_BURN_ROLE` to any address, including themselves, which could invalidate access control. Use a multi-sig wallet as owner in production.

3. **Precision Loss**: Interest calculations truncate to wei precision. Amounts smaller than 1 wei may experience precision loss due to integer division.

4. **Interest Rate Arbitrage**: Users can exploit the interest rate system by:
   - Making a small deposit early to lock in the highest interest rate
   - Making larger deposits from new wallets at lower rates
   - Transferring the larger balance to their original high-rate wallet
   - Result: Keeping the higher interest rate on a much larger balance
   - **Mitigation**: Design reward calculations conservatively and monitor for exploits

5. **Compounding via Transfers**: Users can artificially compound interest from linear to exponential growth by:
   - Transferring RBT tokens to themselves repeatedly
   - Each transfer triggers `_mintAccruedInterest()`, resetting the `s_userUpdatedAt` timestamp
   - This increases the principal, which then accrues on the accrued interest
   - **Mitigation**: Contract owner must account for this when calculating vault reserves

**Vault Reserve Considerations:**
- The vault must hold sufficient ETH to cover all outstanding RBT redemptions
- If users extensively use the compounding-via-transfer exploit, actual accrued interest could significantly exceed linear projections
- Monitor vault reserve health and consider implementing withdrawal limits or cooldown periods

**Chainlink CCIP Dependencies:**
- Token bridging relies on Chainlink CCIP infrastructure
- Cross-chain transactions are subject to Chainlink node network conditions and fees
- Bridge delays depend on destination chain finality requirements
- User interest rates are preserved across chains via the `RebaseTokenPool` contract

## Gas Optimization

Generate a detailed gas report for all functions:

```bash
forge test --gas-report
```

Create a gas snapshot (baseline for comparison):

```bash
forge snapshot
```

Compare gas changes against baseline:

```bash
forge snapshot --diff
```

**Key Gas Optimizations Implemented:**
- Interest accrual calculation uses minimal storage reads
- `balanceOf()` is computed on-the-fly rather than stored (saves storage writes)
- Transfer logic avoids looping through user arrays
- CCIP pool operations minimize cross-chain data transmission

**Gas Cost Notes:**
- `deposit()`: ~110-130k gas (varies with state changes)
- `redeem()`: ~55-60k gas (calls + external transfer)
- `transfer()`: ~110-112k gas (includes interest minting for both parties)
- `mint()` with interest accrual: ~32-120k gas

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Disclaimer:** This software is provided "as is", without warranty of any kind. Use at your own risk.

**Built with [Foundry](https://getfoundry.sh/)**
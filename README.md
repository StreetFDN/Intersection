# Street AMM

AMM on **Base** for startup tokens (ERC-S), forked from [Aerodrome Finance](https://github.com/aerodrome-finance/contracts) (Solidly-style). Uses battle-tested core contracts with Street-specific changes: STREET token, 2-year vote-escrow, fixed emissions, founder controls, and 5% bribe platform fee.

- **Spec:** [STREET_AMM_IMPLEMENTATION_SPEC.md](STREET_AMM_IMPLEMENTATION_SPEC.md)
- **Docs:** [docs/](docs/) — [Architecture](docs/ARCHITECTURE.md), [Tokenomics](docs/TOKENOMICS.md), [Governance](docs/GOVERNANCE.md), [Security](docs/SECURITY.md)

## Protocol overview

### AMM contracts (use as-is)

| Contract | Description |
|----------|-------------|
| `Pool.sol` | Constant-product AMM (Uniswap V2–style). |
| `Router.sol` | Multi-pool swaps, add/remove liquidity. |
| `PoolFees.sol` | Pool trading fees (separate from reserves). |
| `ProtocolLibrary.sol` | Router helpers (e.g. price impact). |
| `FactoryRegistry.sol` | Registry of pool, gauge, and voting-reward factories. |

### Token & emissions (Street)

| Contract | Description |
|----------|-------------|
| `StreetToken.sol` | Protocol ERC20 (STREET), 1B max supply. |
| `VeStreet.sol` | Vote-escrow (ve)NFT; max lock **2 years**. Merge, split, managed NFTs. |
| `StreetMinter.sol` | Fixed weekly emissions (no rebases); team share + rest to Voter. |
| `RewardsDistributor.sol` | Used by Minter; no rebase transfers in Street flow. |
| `VeArtProxy.sol` | (ve)NFT art proxy. |
| `AirdropDistributor.sol` | Distributes permanently locked (ve)NFTs. |

### Protocol mechanics

| Contract | Description |
|----------|-------------|
| `StreetVoter.sol` | Epoch votes, gauge/bribe creation, emission distribution. **Founder whitelist** for gauge creation; **gauge pause** (governor or pool founder). |
| `Gauge.sol` | LP staking; receives emissions by vote weight. |
| `StreetBribe.sol` | Bribe rewards with **5% platform fee** to treasury. |
| `FeesVotingReward.sol` | LP fees for current epoch voters. |
| `VotingReward.sol` | Base reward logic. |
| `ManagedReward.sol` / `LockedManagedReward.sol` / `FreeManagedReward.sol` | Managed veNFT staking and rewards. |
| `FounderControls.sol` | Per-pool pause, max daily volume, max float (optional integration). |
| `OffRampKYC.sol` | Optional KYC for fiat off-ramps. |

### Governance (use as-is)

| Contract | Description |
|----------|-------------|
| `ProtocolGovernor.sol` | OpenZeppelin Governor: whitelist, emissions, managed NFTs. |
| `EpochGovernor.sol` | Epoch-based emissions adjustments. |

## Testing

Uses **Foundry**:

```bash
forge install
forge build
forge test
```

## Base mainnet fork tests

Inherit `BaseTest` in `BaseTest.sol` and set `deploymentType` to `Deployment.FORK`. Set `BASE_RPC_URL` in `.env`. Optionally set `BLOCK_NUMBER` for a fixed fork.

## Lint

- `yarn format` — Prettier  
- `yarn lint` — Solhint (currently disabled in CI)

## Deployment

See [script/README.md](script/README.md). Constants (e.g. `script/constants/Base.json`) include `treasury` for StreetBribe and StreetVotingRewardsFactory. Deploy script deploys FounderControls and OffRampKYC and writes addresses to the output JSON.

## Access control

See [PERMISSIONS.md](PERMISSIONS.md) if present.

## Licensing

See LICENSE and NOTICE. This project follows [Apache Foundation](https://infra.apache.org/licensing-howto.html) licensing guidelines.

## Deployment addresses (Aerodrome Base mainnet reference)

The table below refers to **Aerodrome** on Base (upstream). Street AMM deployments will be documented separately after mainnet launch (see `script/constants/output/` for script output).

| Name | Address |
|------|---------|
| ArtProxy | [0xE999…](https://basescan.org/address/0xE9992487b2EE03b7a91241695A58E0ef3654643E#code) |
| RewardsDistributor | [0x227f…](https://basescan.org/address/0x227f65131A261548b057215bB1D5Ab2997964C7d#code) |
| FactoryRegistry | [0x5C3F…](https://basescan.org/address/0x5C3F18F06CC09CA1910767A34a20F771039E37C0#code) |
| Forwarder | [0x15e6…](https://basescan.org/address/0x15e62707FCA7352fbE35F51a8D6b0F8066A05DCc#code) |
| GaugeFactory | [0x35f3…](https://basescan.org/address/0x35f35cA5B132CaDf2916BaB57639128eAC5bbcb5#code) |
| ManagedRewardsFactory | [0xFdA1…](https://basescan.org/address/0xFdA1fb5A2a5B23638C7017950506a36dcFD2bDC3#code) |
| Minter | [0xeB01…](https://basescan.org/address/0xeB018363F0a9Af8f91F06FEe6613a751b2A33FE5#code) |
| PoolFactory | [0x420D…](https://basescan.org/address/0x420DD381b31aEf6683db6B902084cB0FFECe40Da#code) |
| Router | [0xcF77…](https://basescan.org/address/0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43#code) |
| AERO | [0x9401…](https://basescan.org/address/0x940181a94A35A4569E4529A3CDfB74e38FD98631#code) |
| Voter | [0x1661…](https://basescan.org/address/0x16613524e02ad97eDfeF371bC883F2F5d6C480A5#code) |
| VotingEscrow | [0xeBf4…](https://basescan.org/address/0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4#code) |
| VotingRewardsFactory | [0x45cA…](https://basescan.org/address/0x45cA74858C579E717ee29A86042E0d53B252B504#code) |
| Pool | [0xA4e4…](https://basescan.org/address/0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7#code) |

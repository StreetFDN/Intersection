# Street AMM – Deliverables & To-Do List

**Use this file as your single checklist.** Everything you need to do next, in order, with **how** and **links** so you can move fast.

---

## What’s already done

- **Phases 1–8 implemented:** StreetToken, VeStreet, StreetVoter, StreetMinter, StreetBribe, StreetVotingRewardsFactory, FounderControls, OffRampKYC, deployment scripts (Forge + Hardhat), constants (treasury, etc.), and docs (ARCHITECTURE, TOKENOMICS, GOVERNANCE, SECURITY, README).
- **IDE:** `.vscode/settings.json` and `foundry.toml` solc_version set for clean Solidity diagnostics; IVoter pragma and DeployArtProxy Script import fixed.

---

## 1. Environment & repo setup

**Goal:** One-time setup so you can build, test, and deploy.

| # | Task | How | Links |
|---|------|-----|-------|
| 1.1 | Copy env template | `cp .env.example .env` then fill in values. | — |
| 1.2 | Set `PRIVATE_KEY_DEPLOY` | Use the key that will sign deploy txs (testnet first). | — |
| 1.3 | Set `CONSTANTS_FILENAME`, `OUTPUT_FILENAME` | e.g. `Base.json` for both (or `ci.json` for CI). | `script/README.md` |
| 1.4 | Set `BASE_RPC_URL` | Required for fork tests and Base deployment. Get a free RPC. | [Base docs – RPC](https://docs.base.org/network-information#rpc-endpoints), [Alchemy](https://www.alchemy.com/), [QuickNode](https://www.quicknode.com/) |
| 1.5 | Set `BASE_SCAN_API_KEY` (optional) | For contract verification on Base. | [BaseScan – Get API key](https://basescan.org/apis) |
| 1.6 | Install Foundry | `curl -L https://foundry.paradigm.xyz \| bash` then `foundryup`. | [Foundry book – Installation](https://book.getfoundry.sh/getting-started/installation) |
| 1.7 | Install deps & build | `forge install` (if needed), `forge build`. | — |

**Check:** `forge build` completes; `source .env` then `echo $BASE_RPC_URL` shows your URL.

---

## 2. Run & fix tests

**Goal:** Full test suite green locally and in CI.

| # | Task | How | Links |
|---|------|-----|-------|
| 2.1 | Run all tests | `CONSTANTS_FILENAME=Base.json OUTPUT_FILENAME=ci.json forge test -vvv` (set `BASE_RPC_URL` in `.env` for fork tests). | — |
| 2.2 | Run only unit tests (no fork) | `forge test --no-match-path "test/Deploy.t.sol" -vv` (or exclude fork tests if any). | [Forge – Testing](https://book.getfoundry.sh/forge/writing-tests) |
| 2.3 | Fix any failing tests | Focus on `Minter.t.sol` if it still assumes old emissions; align with StreetMinter schedule. | `test/StreetMinter.t.sol`, `test/BaseTest.sol` |
| 2.4 | Run CI locally | Same env as GitHub: `OUTPUT_FILENAME=ci.json CONSTANTS_FILENAME=Base.json AIRDROPS_FILENAME=airdrop-ci.json forge test -vvv`. | `.github/workflows/main.yml` |
| 2.5 | Add missing secrets in GitHub | Repo → Settings → Secrets: `BASE_RPC_URL`, `PRIVATE_KEY_DEPLOY` (test key only). | [GitHub – Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets) |

**Check:** `forge test` exits 0; CI workflow passes on push/PR.

---

## 3. Deployment constants & scripts (dry run)

**Goal:** Constants and scripts ready for testnet/mainnet; no broadcast yet.

| # | Task | How | Links |
|---|------|-----|-------|
| 3.1 | Prepare constants file | Copy `script/constants/TEMPLATE.json` to e.g. `script/constants/Base.json`. Fill `team`, `treasury`, `feeManager`, `emergencyCouncil`, `allowedManager`, `WETH`, `whitelistTokens`, `pools`, `minter.liquid`, `minter.locked`. | `script/constants/Base.json`, `script/README.md` |
| 3.2 | Prepare airdrop file | Copy `script/constants/AirdropTEMPLATE.json` to e.g. `script/constants/airdrop.json`. Set wallets and amounts. | `script/constants/airdrop-ci.json` (example) |
| 3.3 | Dry-run DeployCore | `forge script script/DeployCore.s.sol:DeployCore --rpc-url base -vvvv` (no `--broadcast`). Fix any revert. | [Forge – Scripts](https://book.getfoundry.sh/forge/scripts) |
| 3.4 | Dry-run DeployGaugesAndPools | After DeployCore output exists: `forge script script/DeployGaugesAndPools.s.sol:DeployGaugesAndPools --rpc-url base -vvvv`. | `script/README.md` |
| 3.5 | Dry-run DistributeAirdrops | Same; ensure airdrop file and output paths match. | `script/README.md` |
| 3.6 | Dry-run DeployGovernors | Same. | `script/README.md` |

**Check:** All scripts run without `--broadcast` and no unexpected reverts.

---

## 4. Security: internal review & external audit

**Goal:** Internal pass done; external audit scheduled/completed; findings fixed.

| # | Task | How | Links |
|---|------|-----|-------|
| 4.1 | Internal review | Review every modified/new file: StreetToken, VeStreet, StreetVoter, StreetMinter, StreetBribe, StreetVotingRewardsFactory, FounderControls, OffRampKYC. Check access control, math, and edge cases. | `docs/SECURITY.md`, `STREET_AMM_IMPLEMENTATION_SPEC.md` (Risk Assessment) |
| 4.2 | Run Slither (optional) | Already in CI (`slither-static-analysis`). Run locally: install Slither, run on `contracts/`. | [Slither](https://github.com/crytic/slither) |
| 4.3 | Engage external auditor | E.g. Trail of Bits or OpenZeppelin; scope = all Street-specific and touched contracts. | [Trail of Bits](https://www.trailofbits.com/), [OpenZeppelin – Audits](https://www.openzeppelin.com/security-audits) |
| 4.4 | Fix audit findings | Triage and fix (or document accepted risk). Re-run tests and scripts. | — |
| 4.5 | Publish audit report | Make report public (e.g. repo `audits/` or docs site). | `STREET_AMM_IMPLEMENTATION_SPEC.md` (Phase 3) |

**Check:** Internal review done; audit scope agreed; post-audit fixes merged and tests green.

---

## 5. Multisig & governance setup

**Goal:** Multisig exists and is planned as owner/team for core contracts.

| # | Task | How | Links |
|---|------|-----|-------|
| 5.1 | Create multisig | Use Gnosis Safe (or equivalent) on Base. | [Safe – Create Safe](https://app.safe.global/), [Base – Safe](https://docs.base.org/tutorials/smart-wallet-setup) |
| 5.2 | Set deployer / team addresses | In constants, set `team` (and `treasury` if different) to the multisig address. | `script/constants/Base.json` |
| 5.3 | Plan ownership transfers | After deploy: transfer ownership of StreetToken, VeStreet, Voter, FactoryRegistry, FounderControls, OffRampKYC, etc. to multisig. | `script/DeployCore.s.sol` (currently transfers to `team`) |
| 5.4 | Document governor flow | Who can call setGovernor, setEpochGovernor, setEmergencyCouncil, whitelistFounder, pauseGauge; timelock if any. | `docs/GOVERNANCE.md` |

**Check:** Multisig live on Base; constants point to it; governance flow documented.

---

## 6. Deploy to Base (testnet then mainnet)

**Goal:** Contracts deployed and verified on Base; post-deploy steps done.

| # | Task | How | Links |
|---|------|-----|-------|
| 6.1 | Deploy Core | `forge script script/DeployCore.s.sol:DeployCore --broadcast --slow --rpc-url base --verify -vvvv` (requires `.env` and constants). | `script/README.md` |
| 6.2 | Accept team on Minter | From `minter.pendingTeam()` call `acceptTeam()` on StreetMinter. | `script/README.md` |
| 6.3 | Deploy gauges and pools | `forge script script/DeployGaugesAndPools.s.sol:DeployGaugesAndPools --broadcast --slow --rpc-url base --verify -vvvv`. | `script/README.md` |
| 6.4 | Distribute airdrops | From airdrop owner: `forge script script/DistributeAirdrops.s.sol:DistributeAirdrops --broadcast --slow --gas-estimate-multiplier 200 --legacy --rpc-url base --verify -vvvv`. | `script/README.md` |
| 6.5 | Deploy governors | `forge script script/DeployGovernors.s.sol:DeployGovernors --broadcast --slow --rpc-url base --verify -vvvv`. | `script/README.md` |
| 6.6 | Set governor addresses | From `escrow.team()`: on Voter call `setEpochGovernor(EpochGovernor)` and `setGovernor(Governor)` (addresses from script output). | `script/README.md` |
| 6.7 | Accept vetoer on Governor | From `escrow.team()`: on ProtocolGovernor call `acceptVetoer()`. | `script/README.md` |
| 6.8 | Verify on BaseScan | If not auto-verified: submit source via BaseScan “Verify Contract”. | [BaseScan – Verify](https://basescan.org/verifyContract) |

**Check:** All script outputs saved (e.g. `script/constants/output/`); contracts verified on BaseScan; team and governors set.

---

## 7. Frontend & docs (public)

**Goal:** Public frontend and docs so users can interact and understand the system.

| # | Task | How | Links |
|---|------|-----|-------|
| 7.1 | Deploy frontend | Build and deploy your app (e.g. street.app/trade) to Base; point to deployed contract addresses. | Your frontend repo; [Base – Build](https://docs.base.org/build/guides) |
| 7.2 | Publish docs | Put ARCHITECTURE, TOKENOMICS, GOVERNANCE, SECURITY (and README) on docs.street.app or repo. | `docs/`, `README.md` |
| 7.3 | Update README deployment table | Replace Aerodrome addresses with Street deployment addresses (or link to a single source of truth). | `README.md` (bottom) |

**Check:** Frontend live; docs accessible; README reflects Street deployment.

---

## 8. Monitoring & operations

**Goal:** Know that the protocol is healthy and catch issues early.

| # | Task | How | Links |
|---|------|-----|-------|
| 8.1 | Track deployment outputs | Keep `script/constants/output/*.json` (or equivalent) as source of truth for addresses. | — |
| 8.2 | Monitor epoch flips & emissions | Ensure `updatePeriod` / distribution runs each week; emissions match StreetMinter schedule. | `docs/TOKENOMICS.md`, `contracts/StreetMinter.sol` |
| 8.3 | Monitor TVL & voting | Track TVL in pools and % of veSTREET voting. | Your analytics or [DefiLlama](https://defillama.com/) |
| 8.4 | Alerts | Set alerts for failed txs, large transfers, or governance actions. | Your infra (e.g. Tenderly, OpenZeppelin Defender) |
| 8.5 | Bug bounty (optional) | Launch a program (e.g. Immunefi) with clear scope and payouts. | [Immunefi](https://immunefi.com/) |

**Check:** You have a list of key addresses and at least one way to notice failed or unusual txs.

---

## 9. Go-live checklist (launch week)

**Goal:** Nothing critical left before launch.

| # | Task | Done |
|---|------|------|
| 9.1 | All contracts deployed to Base mainnet | [ ] |
| 9.2 | Multisig set up and tested | [ ] |
| 9.3 | Initial STREET distribution complete | [ ] |
| 9.4 | 3–5 pools created with seed liquidity | [ ] |
| 9.5 | Gauges created for all pools | [ ] |
| 9.6 | First bribes posted | [ ] |
| 9.7 | Frontend deployed | [ ] |
| 9.8 | Documentation published | [ ] |
| 9.9 | Security audit report public | [ ] |
| 9.10 | Announce (X, Telegram, Discord) | [ ] |
| 9.11 | First epoch flip and emissions run | [ ] |

---

## Quick reference links

| Resource | URL |
|----------|-----|
| Foundry book | https://book.getfoundry.sh/ |
| Base docs | https://docs.base.org/ |
| Base RPC endpoints | https://docs.base.org/network-information#rpc-endpoints |
| BaseScan | https://basescan.org/ |
| BaseScan API | https://basescan.org/apis |
| Safe (multisig) | https://app.safe.global/ |
| Trail of Bits | https://www.trailofbits.com/ |
| OpenZeppelin audits | https://www.openzeppelin.com/security-audits |
| Immunefi | https://immunefi.com/ |
| Project spec | `STREET_AMM_IMPLEMENTATION_SPEC.md` |
| Deployment steps | `script/README.md` |
| Architecture | `docs/ARCHITECTURE.md` |
| Tokenomics | `docs/TOKENOMICS.md` |
| Governance | `docs/GOVERNANCE.md` |
| Security | `docs/SECURITY.md` |

---

**Start with section 1 (env & setup), then 2 (tests), then 3 (dry-run scripts).** After that, security (4) and multisig (5) can run in parallel with deployment prep; then deploy (6), frontend/docs (7), and monitoring (8). Use section 9 as the final go/no-go list before launch.

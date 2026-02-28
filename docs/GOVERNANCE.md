# Street AMM – Governance

Street reuses Aerodrome-style governance: protocol governor (OpenZeppelin Governor) and optional EpochGovernor for emissions tuning.

## Roles

- **Governor (ProtocolGovernor):** Protocol-wide parameter changes, whitelist, managed NFT creation. Requires veSTREET voting and timelock.
- **Epoch governor:** Epoch-level settings (e.g. emissions nudge); can be same as team multisig.
- **Emergency council (StreetVoter):** Can pause in emergencies.
- **Team:** Set on VeStreet, Minter; receives team share of emissions. Often multisig.
- **Pool founder (per pool):** Registered in FounderControls; can pause that pool and set volume/float limits. Governor can also pause gauges via StreetVoter.

## Street-specific behavior

1. **Gauge creation (StreetVoter):** Only **whitelisted founders** or the **governor** can create gauges. Governor calls `whitelistFounder(founder, true)` to allow a founder to create gauges for their pool.
2. **Gauge pause:** Governor or the **pool founder** (for that pool) can call `pauseGauge(gauge, true)` so the gauge is skipped in `distribute`.
3. **FounderControls:** Owner (e.g. multisig) registers pool founders; each founder can pause their pool, set max daily volume, and max float (bps) for that pool. Not enforced by Pool.sol unless a custom integration calls `checkSwap`.

## Multisig and ownership

- Core contracts (StreetToken, VeStreet, StreetVoter, FactoryRegistry, FounderControls, etc.) should have ownership transferred to a multisig after deployment.
- Deployment script transfers FounderControls and OffRampKYC ownership to `team` (see `script/DeployCore.s.sol`).

## Epoch

- **Length:** 1 week (604,800 seconds).
- **Start:** Thursday 00:00 UTC (configurable via epoch logic).
- First hour: distribution window (voting disabled in typical setups).
- Last hour: optionally restricted voting (whitelisted only), depending on configuration.

## References

- `contracts/ProtocolGovernor.sol`, `contracts/EpochGovernor.sol`
- `contracts/StreetVoter.sol` (whitelistFounder, pauseGauge)
- `contracts/FounderControls.sol` (registerFounder, setPaused, setMaxDailyVolume, setMaxFloat)
- `STREET_AMM_IMPLEMENTATION_SPEC.md` for full deployment and role setup.

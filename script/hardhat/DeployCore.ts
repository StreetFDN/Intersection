import { deploy, deployLibrary, getContractAt } from "./utils/helpers";
import { writeFile } from "fs/promises";
import { join } from "path";
import { Libraries } from "hardhat/types";
import { BigNumber } from "ethers";
import {
  ManagedRewardsFactory,
  StreetVotingRewardsFactory,
  GaugeFactory,
  PoolFactory,
  FactoryRegistry,
  Pool,
  StreetMinter,
  RewardsDistributor,
  AirdropDistributor,
  Router,
  StreetToken,
  StreetVoter,
  VeArtProxy,
  VeStreet,
  IERC20,
  ProtocolForwarder,
  FounderControls,
  OffRampKYC,
} from "../../artifacts/types";
import jsonConstants from "../constants/Base.json";

interface ProtocolOutput {
  AirdropDistributor: string;
  ArtProxy: string;
  Distributor: string;
  FactoryRegistry: string;
  Forwarder: string;
  GaugeFactory: string;
  ManagedRewardsFactory: string;
  Minter: string;
  PoolFactory: string;
  Router: string;
  STREET: string;
  Voter: string;
  VotingEscrow: string;
  VotingRewardsFactory: string;
  FounderControls: string;
  OffRampKYC: string;
}

interface AirdropInfo {
  amount: number;
  wallet: string;
}

async function main() {
  // ====== start _deploySetupBefore() ======
  const ONE = "1000000000000000000";
  const AIRDROPPER_BALANCE = 200_000_000;
  const DECIMAL = BigNumber.from(10).pow(18);

  const treasury =
    (jsonConstants as { treasury?: string }).treasury ||
    jsonConstants.team;
  const STREET = await deploy<StreetToken>("StreetToken");
  jsonConstants.whitelistTokens.push(STREET.address);
  // ====== end _deploySetupBefore() ======

  // ====== start _coreSetup() ======

  // ====== start deployFactories() ======
  const implementation = await deploy<Pool>("Pool");

  const poolFactory = await deploy<PoolFactory>(
    "PoolFactory",
    undefined,
    implementation.address
  );
  await poolFactory.setFee(true, 1);
  await poolFactory.setFee(false, 1);

  const votingRewardsFactory = await deploy<StreetVotingRewardsFactory>(
    "StreetVotingRewardsFactory",
    undefined,
    treasury
  );

  const gaugeFactory = await deploy<GaugeFactory>("GaugeFactory");

  const managedRewardsFactory = await deploy<ManagedRewardsFactory>(
    "ManagedRewardsFactory"
  );

  const factoryRegistry = await deploy<FactoryRegistry>(
    "FactoryRegistry",
    undefined,
    poolFactory.address,
    votingRewardsFactory.address,
    gaugeFactory.address,
    managedRewardsFactory.address
  );
  // ====== end deployFactories() ======

  const forwarder = await deploy<ProtocolForwarder>("ProtocolForwarder");

  const balanceLogicLibrary = await deployLibrary("BalanceLogicLibrary");
  const delegationLogicLibrary = await deployLibrary("DelegationLogicLibrary");
  const libraries: Libraries = {
    BalanceLogicLibrary: balanceLogicLibrary.address,
    DelegationLogicLibrary: delegationLogicLibrary.address,
  };

  const escrow = await deploy<VeStreet>(
    "VeStreet",
    libraries,
    forwarder.address,
    STREET.address,
    factoryRegistry.address
  );

  const trig = await deployLibrary("Trig");
  const perlinNoise = await deployLibrary("PerlinNoise");
  const artLibraries: Libraries = {
    Trig: trig.address,
    PerlinNoise: perlinNoise.address,
  };

  const artProxy = await deploy<VeArtProxy>(
    "VeArtProxy",
    artLibraries,
    escrow.address
  );
  await escrow.setArtProxy(artProxy.address);

  const distributor = await deploy<RewardsDistributor>(
    "RewardsDistributor",
    undefined,
    escrow.address
  );

  const voter = await deploy<StreetVoter>(
    "StreetVoter",
    undefined,
    forwarder.address,
    escrow.address,
    factoryRegistry.address
  );

  await escrow.setVoterAndDistributor(voter.address, distributor.address);

  const router = await deploy<Router>(
    "Router",
    undefined,
    forwarder.address,
    factoryRegistry.address,
    poolFactory.address,
    voter.address,
    jsonConstants.WETH
  );

  const minter = await deploy<StreetMinter>(
    "StreetMinter",
    undefined,
    voter.address,
    escrow.address,
    distributor.address
  );
  await distributor.setMinter(minter.address);
  await STREET.setMinter(minter.address);

  const airdrop = await deploy<AirdropDistributor>(
    "AirdropDistributor",
    undefined,
    escrow.address
  );

  await voter.initialize(jsonConstants.whitelistTokens, minter.address);
  // ====== end _coreSetup() ======

  // ====== start _deploySetupAfter() ======

  // Minter initialization
  let lockedAirdropInfo: AirdropInfo[] = jsonConstants.minter.locked;
  let liquidAirdropInfo: AirdropInfo[] = jsonConstants.minter.liquid;

  let liquidWallets: string[] = [];
  let lockedWallets: string[] = [];
  let liquidAmounts: BigNumber[] = [];
  let lockedAmounts: BigNumber[] = [];

  // First add the AirdropDistributor's address and its amount
  liquidWallets.push(airdrop.address);
  liquidAmounts.push(BigNumber.from(AIRDROPPER_BALANCE).mul(DECIMAL));

  liquidAirdropInfo.forEach((drop) => {
    liquidWallets.push(drop.wallet);
    liquidAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  lockedAirdropInfo.forEach((drop) => {
    lockedWallets.push(drop.wallet);
    lockedAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  await minter.initialize({
    liquidWallets: liquidWallets,
    liquidAmounts: liquidAmounts,
    lockedWallets: lockedWallets,
    lockedAmounts: lockedAmounts,
  });

  // Set protocol state to team
  await escrow.setTeam(jsonConstants.team);
  await minter.setTeam(jsonConstants.team);
  await poolFactory.setPauser(jsonConstants.team);
  await voter.setEmergencyCouncil(jsonConstants.team);
  await voter.setEpochGovernor(jsonConstants.team);
  await voter.setGovernor(jsonConstants.team);
  await factoryRegistry.transferOwnership(jsonConstants.team);

  await poolFactory.setFeeManager(jsonConstants.feeManager);
  await poolFactory.setVoter(voter.address);

  const founderControls = await deploy<FounderControls>("FounderControls");
  await founderControls.transferOwnership(jsonConstants.team);
  const offRampKYC = await deploy<OffRampKYC>("OffRampKYC");
  await offRampKYC.transferOwnership(jsonConstants.team);

  // ====== end _deploySetupAfter() ======

  const outputDirectory = "script/constants/output";
  const outputFile = join(
    process.cwd(),
    outputDirectory,
    "ProtocolOutput.json"
  );

  const output: ProtocolOutput = {
    AirdropDistributor: airdrop.address,
    ArtProxy: artProxy.address,
    Distributor: distributor.address,
    FactoryRegistry: factoryRegistry.address,
    Forwarder: forwarder.address,
    GaugeFactory: gaugeFactory.address,
    ManagedRewardsFactory: managedRewardsFactory.address,
    Minter: minter.address,
    PoolFactory: poolFactory.address,
    Router: router.address,
    STREET: STREET.address,
    Voter: voter.address,
    VotingEscrow: escrow.address,
    VotingRewardsFactory: votingRewardsFactory.address,
    FounderControls: founderControls.address,
    OffRampKYC: offRampKYC.address,
  };

  try {
    await writeFile(outputFile, JSON.stringify(output, null, 2));
  } catch (err) {
    console.error(`Error writing output file: ${err}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

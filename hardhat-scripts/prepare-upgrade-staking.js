const { ethers, upgrades } = require("hardhat");

// sepolia
const upgradeManifest = require("../.openzeppelin/unknown-11155111.json");

async function main() {
  const proxyAddress =
    process.env.STAKING || upgradeManifest?.proxies[0]?.address;

  if (!proxyAddress) {
    throw new Error("Unable to determine proxy address");
  }

  console.info(`Upgrading proxy ${proxyAddress}`);

  // Re-deploy the StakingUtils Library
  const StakingUtilsLibrary = await ethers.getContractFactory("StakingUtils");
  const stakingUtils = await StakingUtilsLibrary.deploy();
  console.info("Deployed fresh StakingUtils library: ", stakingUtils.address);
  await stakingUtils.deployed();

  const contractFactoryOptions = {
    libraries: {
      StakingUtils: stakingUtils.address,
    },
  };

  const Staking = await ethers.getContractFactory(
    "Staking",
    contractFactoryOptions,
  );
  const newImplementation = await upgrades.prepareUpgrade(proxyAddress, Staking, {
    kind: "uups",
    // Explicit consent - external library being linked (LibraryUtils) is safe, does not call selfdestruct
    unsafeAllow: ["external-library-linking"],
  });

  console.info("Staking new implementation (not upgraded yet): ", newImplementation);
}

main();

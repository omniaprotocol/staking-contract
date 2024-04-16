const { ethers } = require("hardhat");

async function main() {
  const Token = await ethers.getContractFactory("ERC20Mock");
  const token = await Token.deploy();
  console.info("Token: ", token.address);
  await token.deployed();

  const StakingUtilsLibrary = await ethers.getContractFactory("StakingUtils");
  const stakingUtils = await StakingUtilsLibrary.deploy();
  console.info("StakingUtils library: ", stakingUtils.address);
  await stakingUtils.deployed();

  const contractFactoryOptions = {
    libraries: {
      StakingUtils: stakingUtils.address,
    },
  };

  const StakingSettings = await ethers.getContractFactory(
    "StakingSettings",
    contractFactoryOptions,
  );

  const settings = await StakingSettings.deploy();
  console.info("StakingSettings: ", settings.address);
  await settings.deployed();

  const Staking = await ethers.getContractFactory(
    "Staking",
    contractFactoryOptions,
  );
  const proxy = await upgrades.deployProxy(
    Staking,
    [token.address, settings.address],
    {
      kind: "uups",
      // Explicit consent - external library being linked (LibraryUtils) is safe, does not call selfdestruct
      unsafeAllow: ["external-library-linking"],
    },
  );
  console.info("Staking: ", proxy.address);

  await proxy.deployed();
}

main();

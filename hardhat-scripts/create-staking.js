const { ethers } = require("hardhat");

async function main() {
  const Token = await ethers.getContractFactory("ERC20");
  const token = await Token.deploy();
  console.info("Token: ", token.address);
  await token.deployed();

  const settings = await StakingSettings.deploy();
  console.info("StakingSettings: ", settings.address);
  await settings.deployed();

  const Staking = await ethers.getContractFactory("Staking");
  const proxy = await upgrades.deployProxy(
    Staking,
    [token.address, settings.address],
    {
      kind: "uups",
    },
  );
  console.info("Staking: ", proxy.address);

  await proxy.deployed();
}

main();

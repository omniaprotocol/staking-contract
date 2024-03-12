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

  const Staking = await ethers.getContractFactory("Staking");
  await upgrades.upgradeProxy(proxyAddress, Staking, {
    kind: "uups",
  });

  console.info("Upgrade complete");
}

main();

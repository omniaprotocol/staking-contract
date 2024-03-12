const { ethers } = require("hardhat");

async function main() {
  const Staking = await ethers.getContractFactory("Staking");

  const staking = await Staking.attach(process.env["STAKING"]);

  const stakeId =
    "0x0000000000000000000000000000000000000000000000000000000000000001";
  console.log("Staking stake", await staking.getStake(stakeId));
}

main();

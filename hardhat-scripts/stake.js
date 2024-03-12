const { ethers } = require("hardhat");

async function main() {
  const Staking = await ethers.getContractFactory("Staking");
  const Token = await ethers.getContractFactory("ERC20");

  const token = await Token.attach(process.env["TOKEN"]);

  const staking = await Staking.attach(process.env["STAKING"]);

  const nodeId =
    "0x0000000000000000000000000000000000000000000000000000000000000001";
  const amount = (1000 * 10e18).toPrecision(23);
  const stakingDays = 28;

  const approveTx = await token.approve(staking.address, amount);
  await approveTx.wait();

  const stakeTx = await staking.stakeTokens(
    nodeId,
    amount.toString(),
    stakingDays,
  );
  await stakeTx.wait();

  console.log("Staking response", stakeTx);
}

main();

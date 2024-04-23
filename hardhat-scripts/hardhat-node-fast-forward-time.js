const { ethers } = require("hardhat");

const TWO_DAYS_IN_SECONDS = 3600 * 24 * 2;

async function main() {
    await network.provider.send("evm_increaseTime", [TWO_DAYS_IN_SECONDS]);
    console.info(`Node's time has been fast forwarded with ${TWO_DAYS_IN_SECONDS} seconds`);
}


main();
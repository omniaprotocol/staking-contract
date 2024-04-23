const { ethers } = require("hardhat");

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
const BYTES32_ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000"

const { testnetGnosisSafeOwnersPrivateKey } = require("../config.secret.js") || null;

const gnosisSafeAlreadyDeployedAddress = process.env.GNOSIS_SAFE || null;
const timelockAlreadyDeployedAddress = process.env.TIMELOCK_ADMIN || null;
const tokenAlreadyDeployedAddress = process.env.TOKEN || null;

let gnosisSafeAdmin1of3Wallet = null;
let gnosisSafeAdmin2of3Wallet = null;
let gnosisSafeAdmin3of3Wallet = null;

if (!testnetGnosisSafeOwnersPrivateKey) {
  gnosisSafeAdmin1of3Wallet = ethers.Wallet.createRandom();
  gnosisSafeAdmin2of3Wallet = ethers.Wallet.createRandom();
  gnosisSafeAdmin3of3Wallet = ethers.Wallet.createRandom();
} else {
  gnosisSafeAdmin1of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[0]);
  gnosisSafeAdmin2of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[1]);
  gnosisSafeAdmin3of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[2]);
}


async function deployMockGnosisSafe() {
  console.log('Deploying Gnosis Safe contract...');
  const SafeL2 = await ethers.getContractFactory("SafeL2");
  const safeSingleton = await SafeL2.deploy();
  await safeSingleton.deployed();

  const SafeProxyFactory = await ethers.getContractFactory("SafeProxyFactory");
  const proxyFactory = await SafeProxyFactory.deploy();
  await proxyFactory.deployed();

  console.log('Gnosis Safe Wallet owner 1/3: ',gnosisSafeAdmin1of3Wallet.address);
  console.log('Gnosis Safe Wallet owner 2/3: ',gnosisSafeAdmin2of3Wallet.address);
  console.log('Gnosis Safe Wallet owner 3/3: ',gnosisSafeAdmin3of3Wallet.address);
  const threshold = 2;
  console.log(`Gnosis Safe Wallet threshold: ${threshold}/3`);

  const owners = [gnosisSafeAdmin1of3Wallet.address, gnosisSafeAdmin2of3Wallet.address, gnosisSafeAdmin3of3Wallet.address];

  const calldata = SafeL2.interface.encodeFunctionData("setup", [owners, threshold, ADDRESS_ZERO, BYTES32_ZERO, ADDRESS_ZERO, ADDRESS_ZERO, 0, ADDRESS_ZERO]);
  
  const createProxyReceipt = await proxyFactory.createProxyWithNonce(safeSingleton.address, calldata, 1);
  const result = await createProxyReceipt.wait();
  const proxyAddress = result.logs.map( (e) => {
    if (e.address == proxyFactory.address) {
      const parsedEvent = SafeProxyFactory.interface.parseLog(e);
      return parsedEvent.args.proxy;
    }
    return null;
  }).find(x => x != null);

  const gnosisSafe = SafeL2.attach(proxyAddress);
  console.log("Deployed Gnosis safe: ", gnosisSafe.address);
  return gnosisSafe;
}

async function deployTimelockAdmin(gnosiSafeAddress) {
  console.log('Deploying Timelock contract...');
  const TimelockAdmin = await ethers.getContractFactory("TimelockAdmin");
  const timelock = await TimelockAdmin.deploy([gnosiSafeAddress]);
  await timelock.deployed();
  console.log("Deployed TimelockAdmin: ", timelock.address);
  return timelock;
}

async function deployMockToken() {
  console.log("Deploying mock ERC20 token...");
  const Token = await ethers.getContractFactory("ERC20Mock");
  const token = await Token.deploy();
  await token.deployed();
  console.log('Deployed mock ERC20 token: ',token.address);
  return token;
}

async function main() {
  const Token = await ethers.getContractFactory("ERC20Mock");
  const SafeL2 = await ethers.getContractFactory("SafeL2");
  const TimelockAdmin = await ethers.getContractFactory("TimelockAdmin");

  let token;
  if (tokenAlreadyDeployedAddress) {
    token = Token.attach(tokenAlreadyDeployedAddress);
  } else {
    token = await deployMockToken();
  }
  console.log('Using Token contract: ', token.address)

  let gnosisSafe;
  if (gnosisSafeAlreadyDeployedAddress) {
    gnosisSafe = SafeL2.attach(gnosisSafeAlreadyDeployedAddress);
  } else {
    gnosisSafe =  await deployMockGnosisSafe();
  }
  console.log('Using Gnosis Safe contract: ',gnosisSafe.address);

  let timelockAdmin;
  if (timelockAlreadyDeployedAddress) {
    timelockAdmin = TimelockAdmin.attach(timelockAlreadyDeployedAddress);
  } else {
    timelockAdmin = await deployTimelockAdmin(gnosisSafe.address);
  }
  console.log('Using Timelock contract: ',timelockAdmin.address);

  const StakingUtilsLibrary = await ethers.getContractFactory("StakingUtils");
  const stakingUtils = await StakingUtilsLibrary.deploy();
  console.info("Deployed StakingUtils library: ", stakingUtils.address);
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

  const settings = await StakingSettings.deploy(timelockAdmin.address);
  console.info("Deployed StakingSettings: ", settings.address);
  await settings.deployed();

  const Staking = await ethers.getContractFactory(
    "Staking",
    contractFactoryOptions,
  );
  const proxy = await upgrades.deployProxy(
    Staking,
    [token.address, settings.address, timelockAdmin.address],
    {
      kind: "uups",
      // Explicit consent - external library being linked (LibraryUtils) is safe, does not call selfdestruct
      unsafeAllow: ["external-library-linking"],
    },
  );
  console.info("Staking (UUPS proxy): ", proxy.address);

  await proxy.deployed();
}

main();

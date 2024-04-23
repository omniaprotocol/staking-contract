const { ethers, upgrades } = require("hardhat");

const { testnetGnosisSafeOwnersPrivateKey } = require("../config.secret.js") || null;
const gnosisSafeAddress = process.env.GNOSIS_SAFE || null;
const timelockAddress = process.env.TIMELOCK_ADMIN || null;
const proxyAddress = process.env.STAKING || null;
const newImplementationAddress = process.env.NEW_IMPLEMENTATION || null;

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
const BYTES32_ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000";
const TWO_DAYS_IN_SECONDS = 3600 * 24 * 2;

const GAS_LIMIT = 5000000;
const GNOSIS_SAFE_NONCE = process.env.NONCE || 0;

async function main() {

  if (!testnetGnosisSafeOwnersPrivateKey) {
    throw new Error("Unable to determine Gnosis Safe owner wallets");
  }

  if (!gnosisSafeAddress) {
    throw new Error("Unable to determine Gnosis Safe address");
  }

  if (!timelockAddress) {
    throw new Error("Unable to determine Timelock address");
  }

  if (!proxyAddress) {
    throw new Error("Unable to determine proxy address");
  }

  if (!newImplementationAddress) {
    throw new Error("Unable to determine new Staking implementation address");
  }

  const gnosisSafeAdmin1of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[0]);
  const gnosisSafeAdmin2of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[1]);
  const gnosisSafeAdmin3of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[2]);


  console.info(`Upgrading proxy ${proxyAddress} to new implementation ${newImplementationAddress}`);
  console.info(`Using Gnosis Safe: ${gnosisSafeAddress}`);
  console.info(`Using Timelock: ${timelockAddress}`);
  console.info(`Using Gnosis Safe owners: ${gnosisSafeAdmin1of3Wallet.address}, ${gnosisSafeAdmin2of3Wallet.address}, ${gnosisSafeAdmin3of3Wallet.address}`);

  const SafeL2 = await ethers.getContractFactory("SafeL2");

  const multisigInstance = SafeL2.attach(gnosisSafeAddress);
  const TimelockAdmin = await ethers.getContractFactory("TimelockAdmin");

  // The StakingUtils library will not be used, but is needed for the Staking contract factory
  const StakingUtilsLibrary = await ethers.getContractFactory("StakingUtils");
  const stakingUtils = await StakingUtilsLibrary.deploy();
  await stakingUtils.deployed();
  const stakingContractFactoryOptions = {
    libraries: {
      StakingUtils: stakingUtils.address,
    },
  };
  const Staking = await ethers.getContractFactory("Staking", stakingContractFactoryOptions);

  const upgradeCalldata = Staking.interface.encodeFunctionData("upgradeTo", [newImplementationAddress]);
  const scheduleCalldata = TimelockAdmin.interface.encodeFunctionData("schedule",[
          proxyAddress, 0, upgradeCalldata, BYTES32_ZERO, BYTES32_ZERO, TWO_DAYS_IN_SECONDS
  ]);


  let SafeOperation = 0; // 0 is Call, 1 is DelegateCall
  const [hash] = await multisigInstance.functions.getTransactionHash(
      timelockAddress, 0, scheduleCalldata, SafeOperation, GAS_LIMIT, 1, 1, ADDRESS_ZERO, ADDRESS_ZERO, GNOSIS_SAFE_NONCE );

  const byteArrayHash = ethers.utils.arrayify(hash);

  // Sign 2/3 
  const sig1 = await (new ethers.utils.SigningKey(testnetGnosisSafeOwnersPrivateKey[0])).signDigest(byteArrayHash);
  const sig2 = await (new ethers.utils.SigningKey(testnetGnosisSafeOwnersPrivateKey[1])).signDigest(byteArrayHash);
  const packedSig1 = sig1.r + sig1.s.slice(2)+ ethers.utils.hexlify(sig1.v).slice(2);
  const packedSig2 = sig2.r + sig2.s.slice(2)+ ethers.utils.hexlify(sig2.v).slice(2);
  const signatures = packedSig2.concat(packedSig1.slice(2));

  // Fund the gnosis safe just to be sure
  // Create a transaction object
    let tx = {
      to: gnosisSafeAddress,
      // Convert currency unit from ether to wei
      value: ethers.utils.parseEther('1')
  };
  await gnosisSafeAdmin1of3Wallet.connect(ethers.provider).sendTransaction(tx);

  const receipt = await multisigInstance.functions.execTransaction(
      timelockAddress, 0, scheduleCalldata, SafeOperation, GAS_LIMIT, 1, 1, ADDRESS_ZERO, ADDRESS_ZERO, signatures,
  );
  const result = await receipt.wait();
  console.log('Upgrade scheduled');
}

main();

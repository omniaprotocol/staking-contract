const { ethers } = require("hardhat");

const { testnetGnosisSafeOwnersPrivateKey } = require("../config.secret.js") || null;

if (!testnetGnosisSafeOwnersPrivateKey) {
    throw new Error("Unable to determine Gnosis Safe owner wallets");
  }

// Account 0 when running npx hardhat node (should be deterministic)
const richAccountPrivateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

async function main() {
    const gnosisSafeAdmin1of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[0]);
    const gnosisSafeAdmin2of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[1]);
    const gnosisSafeAdmin3of3Wallet = new ethers.Wallet(testnetGnosisSafeOwnersPrivateKey[2]);
    
    // Create a transaction object
    let tx = {
        to: gnosisSafeAdmin1of3Wallet.address,
        // Convert currency unit from ether to wei
        value: ethers.utils.parseEther('100')
    };

    const richWallet = new ethers.Wallet(richAccountPrivateKey).connect(ethers.provider);
    await richWallet.sendTransaction(tx);

    tx = {
        to: gnosisSafeAdmin2of3Wallet.address,
        // Convert currency unit from ether to wei
        value: ethers.utils.parseEther('100')
    };
    await richWallet.sendTransaction(tx);

    tx = {
        to: gnosisSafeAdmin3of3Wallet.address,
        // Convert currency unit from ether to wei
        value: ethers.utils.parseEther('100')
    };
    await richWallet.sendTransaction(tx);
}

main();

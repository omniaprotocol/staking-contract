### Install Foundry

```sh
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

If installation complains about misssing libusb library, on MacOS you can
run the following command to install it.

```sh
brew install libusb
```

After installing the library
start foundry

```sh
foundryup
```

## Install dependencies

```sh
forge install
yarn install
```

## Linting

Linting using solhint

```sh
yarn run lint
```

Formatting using prettier (applies changes)

```sh
yarn run prettify
```

## Building and testing

```sh
forge build
forge test
```

## Deployment

### <b>Hardhat</b>

./hardhat-scripts folder contain both initial deployment (creat-staking.js) and upgrade (upgrade-staking.js) scripts. Hardhat is the recommended deployment method by openZeppelin as it makes extra checks when upgrading that there wouldn't be conflicts and the contract being upgraded to is valid.

To deploy the initial staking contract user:

Local hardhat network

```sh
yarn run deploy:local
```

Sepolia test network

```sh
yarn run deploy:sepolia
```

To upgrade to a new contract version:

Local hardhat network

```sh
yarn run upgrade:local
```

Sepolia test network

```sh
yarn run upgrade:sepolia
```

### <b>Forge</b>

Forge deployment is just manual contract deployment using Forge scripts in ./scripts folder. The script can be run with forges own script command:

```sh
forge script [options] path [args...]
```

More info on options and args [HERE](https://book.getfoundry.sh/reference/forge/forge-script).

### <b>config.secret.js</b>

Expected format is this

```sh
module.exports = {
  testnetPrivateKey: "....",
};

```

## Analyzers

### <b>Slither</b>

Source: https://github.com/crytic/slither\
Version: v0.9.3\
Command: `slither . --filter-paths="test,script" --exclude-dependencies`

Known issues:

- Slither is unable to handle `as Prb` import alias. So to run the analyzer first all aliases have to be removed.
- Some Prb math functions are interpreted as external calls triggering false positive reentrancy errors. Example: `prb.gt` -> greater than compare

### <b>Mythril</b>

Source: https://github.com/ConsenSys/mythril\
Version: v0.23.22\
Command: `myth analyze ./src/Staking.sol --solc-json ./mythril.json`
Files:

- mythril.json is required due to import remapping used by forge. So it simply needs to be coppied from remappings.txt and formatted as a json (test related remappings are optional):

```
{
  "remappings": [
    "openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "openzeppelin-contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/",
    "prb-math/=lib/prb-math/src/",
    "src/=src/"
  ]
}
```

Known issues:

- Unable to handle Prb constants. In Staking.sol contract:\
  `Prb.SD59x18 private constant _ONE = Prb.SD59x18.wrap(1e18);`\
  has to be removed before running.
- Unable to understand proxy "initialize" function, so need to convert initialize to constructor function.

### Deployed addresses

--
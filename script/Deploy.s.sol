// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Staking, StakingSettings} from "src/Staking.sol";
import {ERC20Mock} from "src/mocks/Token.sol";
import {SafeL2, SafeProxyFactory, SafeProxy} from "src/mocks/GnosisSafe.sol";
import {TimelockAdmin} from "src/TimelockAdmin.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDevelopment is Script {
    address[] _gnosisAdmins;

    function run() public {
        vm.startBroadcast();

        SafeL2 adminMultiSig = SafeL2(payable(_deployGnosisSafe()));
        TimelockAdmin timelockAdmin = TimelockAdmin(payable(_deployTimeLockAdmin(address(adminMultiSig))));

        ERC20Mock token = new ERC20Mock();
        StakingSettings settings = new StakingSettings(address(timelockAdmin));
        Staking staking = new Staking();
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking), "");

        staking = Staking(address(proxy));
        staking.initialize(address(token), address(settings), address(timelockAdmin));
        vm.stopBroadcast();
    }

    function _deployGnosisSafe() internal returns (address) {
        SafeL2 safeSingleton = new SafeL2();
        SafeProxyFactory safeFactory = new SafeProxyFactory();
        (address safeAdmin1of3Address, ) = makeAddrAndKey("safeAdmin1of3");
        (address safeAdmin2of3Address, ) = makeAddrAndKey("safeAdmin2of3");
        (address safeAdmin3of3Address, ) = makeAddrAndKey("safeAdmin3of3");

        _gnosisAdmins.push(safeAdmin1of3Address);
        _gnosisAdmins.push(safeAdmin2of3Address);
        _gnosisAdmins.push(safeAdmin3of3Address);
        bytes memory emptyPayload;

        bytes memory setupPayload = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            _gnosisAdmins,
            2,
            address(0),
            emptyPayload,
            address(0),
            address(0),
            0,
            payable(0)
        );
        SafeProxy safeProxy = safeFactory.createProxyWithNonce(address(safeSingleton), setupPayload, 1);
        return address(safeProxy);
    }

    function _deployTimeLockAdmin(address adminMultiSig) internal returns (address) {
        address gnosiSafeAdmin = address(adminMultiSig);
        address[] memory proposersExecutorsCancellers = new address[](1);
        proposersExecutorsCancellers[0] = gnosiSafeAdmin;
        TimelockAdmin timelockAdmin = new TimelockAdmin(proposersExecutorsCancellers);
        return address(timelockAdmin);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {Supplychain} from "../src/Supplychain.sol";

contract TokenFactoryScript is Script {
    Supplychain public supplyChain;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        supplyChain = new Supplychain();
        vm.stopBroadcast();
    }
}

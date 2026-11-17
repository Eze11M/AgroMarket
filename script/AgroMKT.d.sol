// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgroFT.sol";
import "../src/AgroNFT.sol";
import "../src/AgroMKT.sol";

contract DeployAgroMKT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        uint256 initialSupply = 10_000_000;
        uint256 collectCeiling = 1_000_000 * 10**18;
        uint256 tier1Value = 100 * 10**18;

        vm.startBroadcast(deployerPrivateKey);

        AgroFT agroFT = new AgroFT(initialSupply, treasury);
        AgroNFT agroNFT = new AgroNFT();
        AgroMKT agroMKT = new AgroMKT(
            address(agroFT),
            address(agroNFT),
            treasury,
            collectCeiling
        );

        agroNFT.changeOrchestrator(address(agroMKT));
        agroMKT.setTier(tier1Value, true);

        vm.stopBroadcast();

        uint256 treasuryPrivateKey = vm.envUint("TREASURY_KEY");
        vm.startBroadcast(treasuryPrivateKey);
        agroFT.approve(address(agroMKT), type(uint256).max);
        vm.stopBroadcast();

        console.log("AgroFT deployed at:", address(agroFT));
        console.log("AgroNFT deployed at:", address(agroNFT));
        console.log("Orchestrator deployed at:", address(agroMKT));
    }
}
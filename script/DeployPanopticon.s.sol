// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UrlThumbnailer} from "../src/UrlThumbnailer.sol";
import {PanopticonRenderer} from "../src/PanopticonRenderer.sol";
import {Panopticon} from "../src/Panopticon.sol";

contract DeployPanopticon is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory networkName = vm.envString("NETWORK");
        address scriptyStorageAddress = vm.envAddress(
            string(abi.encodePacked(networkName, "_SCRIPTY_STORAGE_V2"))
        );
        address scriptyBuilderAddress = vm.envAddress(
            string(abi.encodePacked(networkName, "_SCRIPTY_BUILDER_V2"))
        );
        address ethfsFileStorageAddress = vm.envAddress(
            string(abi.encodePacked(networkName, "_ETHFS_FILE_STORAGE"))
        );
        string memory thumbnailPrefix = vm.envString(
            string(abi.encodePacked(networkName, "_THUMBNAIL_PREFIX"))
        );
        string memory thumbnailSuffix = vm.envString(
            string(abi.encodePacked(networkName, "_THUMBNAIL_SUFFIX"))
        );

        vm.startBroadcast(deployerPrivateKey);

        // Deploy thumbnailer
        console.log("Deploying thumbnailer");
        UrlThumbnailer thumbnailer = new UrlThumbnailer(
            thumbnailPrefix,
            thumbnailSuffix
        );
        console.log("Thumbnailer deployed to: ", address(thumbnailer));

        // Deploy renderer
        console.log("Deploying renderer");
        PanopticonRenderer renderer = new PanopticonRenderer(
            scriptyStorageAddress,
            scriptyBuilderAddress,
            ethfsFileStorageAddress,
            address(thumbnailer)
        );
        console.log("Renderer deployed to: ", address(renderer));

        // Deploy Panopticon
        console.log("Deploying Panopticon");
        Panopticon panopticon = new Panopticon(
            600, // Max supply
            100, // Max reserve supply,
            address(renderer)
        );
        console.log("Panopticon deployed to: ", address(panopticon));

        vm.stopBroadcast();
    }

    function compare(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }
}

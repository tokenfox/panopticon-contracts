// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/UrlThumbnailer.sol";

contract UrlThumbnailerTest is Test, Freezable {
    UrlThumbnailer public thumbnailer;

    function setUp() public {
        thumbnailer = new UrlThumbnailer(
            "https://example.com/",
            ".png"
        );
    }

    function testGetThumbnailUrl() public {
        bytes memory thumbnailUrl = thumbnailer.getThumbnailUrl(13239);

        assertEq(thumbnailUrl, bytes("https://example.com/13239.png"));
    }

    function testSetConfig() public {
        thumbnailer.setConfig("ipfs://hash/", "");
        bytes memory thumbnailUrl = thumbnailer.getThumbnailUrl(4201);

        assertEq(thumbnailUrl, bytes("ipfs://hash/4201"));
    }

    function testSetConfigWhenNotOwner(address caller) public {
        vm.assume(caller != thumbnailer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        thumbnailer.setConfig("https://rugpull.example.com/", "");
    }

    function testSetConfigWhenFrozen() public {
        thumbnailer.freeze();
        vm.expectRevert(Frozen.selector);
        thumbnailer.setConfig("", "");
    }
}

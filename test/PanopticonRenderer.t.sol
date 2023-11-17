// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "solady/utils/Base64.sol";
import "solady/utils/LibString.sol";
import {FileStore} from "ethfs/packages/contracts/src/FileStore.sol";
import {File} from "ethfs/packages/contracts/src/File.sol";
import {ContentStore} from "ethfs/packages/contracts/src/ContentStore.sol";
import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";
import "scripty.sol/scripty/ScriptyBuilderV2.sol";
import "scripty.sol/scripty/ScriptyStorage.sol";
import {ETHFSFileStorage} from "scripty.sol/scripty/externalStorage/ethfs/ETHFSFileStorage.sol";
import "../src/PanopticonRenderer.sol";
import {UrlThumbnailer} from "../src/UrlThumbnailer.sol";

contract PanopticonRendererTest is Test {
    FileStore public ethfsFileStore;
    ContentStore public ethfsContentStore;
    ETHFSFileStorage public ethfsFileStorage;
    UrlThumbnailer public urlThumbnailer;
    ScriptyStorage public scriptyStorage;
    ScriptyBuilderV2 public scriptyBuilder;
    PanopticonRenderer public renderer;
    PanopticonRenderer public rendererWithoutThumbnailer;
    uint256 public constant CHUNK_SIZE = 24576;
    uint256 public constant NOT_FOUND = type(uint256).max; // For use with LibString

    function _uploadToEthFs(bytes memory contents, string memory filename) internal {
        uint256 chunkCount = contents.length / CHUNK_SIZE;
        if (contents.length % CHUNK_SIZE > 0) {
            chunkCount++;
        }
        uint256 chunkId = 0;
        bytes32[] memory checksums = new bytes32[](chunkCount);

        scriptyStorage.createScript(filename, bytes(""));
        for (uint256 startIndex = 0; startIndex < contents.length; startIndex += CHUNK_SIZE) {
            uint256 bytesLeft = contents.length - startIndex;
            uint256 chunkSize = bytesLeft > CHUNK_SIZE ? CHUNK_SIZE : bytesLeft;
            bytes memory chunk = BytesLib.slice(contents, startIndex, chunkSize);
            (bytes32 checksum,) = ethfsFileStorage.fileStore().contentStore().addContent(chunk);
            checksums[chunkId] = checksum;
            ++chunkId;
        }

        ethfsFileStorage.fileStore().createFile(filename, checksums);
    }

    function setUp() public {
        ethfsContentStore = new ContentStore();
        ethfsFileStore = new FileStore(ethfsContentStore);
        ethfsFileStorage = new ETHFSFileStorage(address(ethfsFileStore));

        scriptyBuilder = new ScriptyBuilderV2();
        scriptyStorage = new ScriptyStorage(address(ethfsContentStore));

        urlThumbnailer = new UrlThumbnailer(
            "https://preview.example.com/",
            "/thumbnail.jpeg"
        );

        // Store p5-v1.5.0.min.js.gz
        _uploadToEthFs(bytes(Base64.encode(vm.readFileBinary("assets/p5-v1.5.0.min.js.gz"))), "p5-v1.5.0.min.js.gz");

        // Store gunzipScripts-0.0.1.js
        _uploadToEthFs(
            bytes(Base64.encode(vm.readFileBinary("assets/gunzipScripts-0.0.1.js"))), "gunzipScripts-0.0.1.js"
        );

        renderer = new PanopticonRenderer(
            address(scriptyStorage),
            address(scriptyBuilder),
            address(ethfsFileStorage),
            address(urlThumbnailer)
        );

        rendererWithoutThumbnailer = new PanopticonRenderer(
            address(scriptyStorage),
            address(scriptyBuilder),
            address(ethfsFileStorage),
            address(0)
        );
    }

    function testDescription() public {
        assertTrue(
            LibString.eq(
                renderer.description(),
                "Are you looking at it, or is it looking at you?"
            ),
            "Description must match the designed one"
        );
    }

    function testGetHTML() public {
        uint256 tokenHash = _generateRandomUint256("seed-1");
        string memory html = renderer.getHTML(1, tokenHash);

        assertTrue(LibString.eq(LibString.slice(html, 0, 6), "<html>"), "HTML should start with <html>");
    }

    function testTokenURI() public {
        uint256 tokenHash = _generateRandomUint256("seed-3");
        string memory tokenUri = renderer.tokenURI(1, tokenHash);
        string memory json = string(Base64.decode(LibString.slice(tokenUri, 29)));

        assertTrue(
            LibString.eq(LibString.slice(tokenUri, 0, 29), "data:application/json;base64,"),
            "tokenURI should have header for base64 encoded data URI"
        );
        assertNotEq(
            LibString.indexOf(json, '"image"'),
            NOT_FOUND,
            "JSON inside tokenURI must include image attribute"
        );
        assertNotEq(
            LibString.indexOf(json, '"animation_url"'),
            NOT_FOUND,
            "JSON inside tokenURI must include animation_url attribute"
        );
    }

    function testTokenURINoThumbnail() public {
        uint256 tokenHash = _generateRandomUint256("seed-3");
        string memory tokenUri = rendererWithoutThumbnailer.tokenURI(1, tokenHash);
        uint256 imageAttrIndex = LibString.indexOf(tokenUri, '"image"');

        assertEq(
            NOT_FOUND,
            imageAttrIndex,
            "tokenURI without thumbnailer must not contain image attribute"
        );
    }

    function testGetMetadata() public {
        uint256 tokenHash = _generateRandomUint256("seed-2");
        string memory metadata = renderer.getMetadata(599, tokenHash);

        assertTrue(LibString.eq(LibString.slice(metadata, 0, 8), '{"name":'), 'Metadata should start with {"name":');
    }

    function testGetName() public {
        assertEq("Panopticon #777", renderer.getName(777));
        assertEq("Panopticon #1", renderer.getName(1));
    }

    function testGetImageNullThumbnailer() public {
        string memory result = rendererWithoutThumbnailer.getImage(231, 0x00);

        assertEq("", result);
    }

    function testGetImageUrlThumbnailer() public {
        string memory result = renderer.getImage(231, 0x00);

        assertEq("https://preview.example.com/231/thumbnail.jpeg", result);
    }

    function testSetConfigUpdatetoIPFS() public {
        UrlThumbnailer ipfsThumbnailer = new UrlThumbnailer(
            "ipfs://bafybeib2zkka7bqpuucbbirwu2g6vjen66buetxovijrafsh7wuhdjvdbu/",
            ".png"
        );

        renderer.setConfig(
            address(scriptyStorage), address(scriptyBuilder), address(ethfsFileStorage), address(urlThumbnailer)
        );

        assertEq("ipfs://bafybeib2zkka7bqpuucbbirwu2g6vjen66buetxovijrafsh7wuhdjvdbu/", ipfsThumbnailer.prefix());
        assertEq(".png", ipfsThumbnailer.suffix());
        assertEq(
            "ipfs://bafybeib2zkka7bqpuucbbirwu2g6vjen66buetxovijrafsh7wuhdjvdbu/0.png",
            ipfsThumbnailer.getThumbnailUrl(0)
        );
        assertEq(
            "ipfs://bafybeib2zkka7bqpuucbbirwu2g6vjen66buetxovijrafsh7wuhdjvdbu/599.png",
            ipfsThumbnailer.getThumbnailUrl(599)
        );
    }

    function testSetConfigWhenNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.setConfig(address(0), address(0), address(0), address(0));
    }

    function testSetConfigWhenFrozen() public {
        renderer.freeze();
        vm.expectRevert(Frozen.selector);
        renderer.setConfig(
            address(scriptyStorage), address(scriptyBuilder), address(ethfsFileStorage), address(urlThumbnailer)
        );
    }

    function testFreezeNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.freeze();
    }

    function testSetScriptNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.setScript("");
    }

    function testSetDescriptionNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.setDescription("");
    }

    function testSetScript() public {
        renderer.setScript("new script");
        assertEq("new script", renderer.script());
    }

    function testSetDescription() public {
        renderer.setDescription("new desc");
        assertEq("new desc", renderer.description());
    }

    function testSetStylesNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.setStyles("");
    }

    function testSetStyles() public {
        assertEq(address(this), renderer.owner());
        renderer.setStyles("new styles");
        assertEq("new styles", renderer.styles());
    }

    function testSetUiNotOwner(address caller) public {
        vm.assume(caller != renderer.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        renderer.setUi("");
    }

    function testSetUi() public {
        renderer.setUi("new ui");
        assertEq("new ui", renderer.ui());
    }

    function testSetUiFrozen() public {
        renderer.freeze();
        vm.expectRevert(Frozen.selector);
        renderer.setUi("new ui");
    }

    function testBatch() public {
        console.log("Generate test batch of renderer outputs");
        for (uint256 i = 0; i <= 20; i++) {
            console.log("Generate output ", i);
            string memory seed = string(abi.encodePacked("seedprefix1234asd", LibString.toString(i)));
            uint256 tokenHash = _generateRandomUint256(seed);
            string memory html = renderer.getHTML(i, tokenHash);
            string memory metadata = renderer.getMetadata(i, tokenHash);
            vm.writeFile(string.concat("generated/html/", LibString.toString(i), ".html"), html);
            vm.writeFile(string.concat("generated/json/", LibString.toString(i), ".json"), metadata);
        }
    }

    function _generateRandomUint256(string memory seed) internal returns (uint256) {
        VmSafe.Wallet memory wallet = vm.createWallet(seed);
        return uint256(keccak256(abi.encode(wallet.publicKeyX, wallet.publicKeyY)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Panopticon.sol";
import "./MockRenderer.sol";
import {Frozen} from "../src/Freezable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

contract MockWallet is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract PanopticonTest is Test, MockWallet {
    Panopticon public panopticon;
    MockWallet public mockWallet1;
    MockRenderer public mockRenderer;
    uint16 public constant TEST_MAX_SUPPLY = 3;
    uint16 public constant TEST_RESERVE_MAX_SUPPLY = 2;
    bytes4 public constant INTERFACE_ERC165 = 0x01ffc9a7;
    bytes4 public constant INTERFACE_ERC1155 = 0xd9b67a26;
    bytes4 public constant INTERFACE_ERC721 = 0x80ac58cd;
    bytes4 public constant INTERFACE_ERC721_METADATA = 0x5b5e139f;
    bytes4 public constant INTERFACE_ERC721_TOKEN_RECEIVER = 0x150b7a02;
    bytes4 public constant INTERFACE_ERC721_ENUMERABLE = 0x780e9d63;
    mapping(uint256 => uint256) internal _usedHashes;

    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    function setUp() public {
        mockWallet1 = new MockWallet();
        mockRenderer = new MockRenderer();
        panopticon = new Panopticon(
            TEST_MAX_SUPPLY,
            TEST_RESERVE_MAX_SUPPLY,
            address(mockRenderer)
        );
        vm.roll(128); // token hash generator requires minimum of 128 minted blocks
    }

    function testMaxSupply() public {
        assertEq(panopticon.tokenIdMax(), TEST_MAX_SUPPLY);
    }

    function testSetMinterAsOwner() public {
        panopticon.setMinter(msg.sender);

        assertEq(msg.sender, panopticon.minter());
    }

    function testSetMinterWhenNotOwner(address caller) public {
        vm.assume(caller != panopticon.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        panopticon.setMinter(msg.sender);
    }

    function testSetRenderer(IPanopticonRenderer renderer) public {
        panopticon.setRenderer(renderer);

        assertEq(address(renderer), address(panopticon.renderer()));
    }

    function testSetRendererMustFailAfterFrozen(IPanopticonRenderer renderer) public {
        panopticon.freeze();
        vm.expectRevert(Frozen.selector);
        panopticon.setRenderer(renderer);
    }

    function testFreezeFailsOnSecondCall() public {
        panopticon.freeze();
        vm.expectRevert(Frozen.selector);
        panopticon.freeze();
    }

    function testSetRendererImplementsERC4906(IPanopticonRenderer renderer) public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        vm.expectEmit();
        emit BatchMetadataUpdate(0, 0);
        panopticon.setRenderer(renderer);

        assertEq(address(renderer), address(panopticon.renderer()));
    }

    function testSetRendererWhenNotOwner(address caller, IPanopticonRenderer renderer) public {
        vm.assume(caller != panopticon.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        panopticon.setRenderer(renderer);
    }

    function testRefreshMetadataMustFailAfterFrozen(IPanopticonRenderer renderer) public {
        panopticon.freeze();
        vm.expectRevert(Frozen.selector);
        panopticon.refreshMetadata();
    }

    function testRefreshMetadataImplementsERC4906() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        panopticon.mint(address(this));
        vm.expectEmit();
        emit BatchMetadataUpdate(0, 1);
        panopticon.refreshMetadata();
    }

    function testRefreshMetadataWhenNotOwner(address caller) public {
        vm.assume(caller != panopticon.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        panopticon.refreshMetadata();
    }

    function testCloseMintZeroSupply() public {
        panopticon.endMint();

        assertEq(panopticon.tokenIdMax(), 0);
    }

    function testEndMintCutsRemainingSupply() public {
        vm.assume(panopticon.tokenIdMax() > 2);

        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        panopticon.mint(address(this));
        panopticon.endMint();

        assertEq(panopticon.tokenIdMax(), 2);

        // Repeated calls to endMint must fail (no supply left to cut)
        vm.expectRevert(NoSupplyLeft.selector);
        panopticon.endMint();
        assertEq(panopticon.tokenIdMax(), 2);
    }

    function testMintWhenSupplyLeft(address mintTo) public {
        vm.assume(mintTo != address(0));
        panopticon.setMinter(address(this));
        panopticon.mint(address(mockWallet1));

        assertEq(panopticon.currentTokenId(), 1);
    }

    function testMintNoSupplyLeft(address addr) public {
        vm.assume(addr != address(0));
        panopticon.setMinter(address(this));
        for (uint256 i = 0; i < TEST_MAX_SUPPLY; i++) {
            panopticon.mint(address(this));
        }

        vm.expectRevert(NoSupplyLeft.selector);
        panopticon.mint(addr);
    }

    function testMintNotMinter(address caller, address minter) public {
        vm.assume(minter != caller);
        vm.assume(caller != panopticon.owner());

        panopticon.setMinter(minter);
        vm.prank(caller);
        vm.expectRevert(NotMinter.selector);
        panopticon.mint(address(this));
    }

    function testMintTokenHashGeneratesUniqueHash() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        panopticon.mint(address(this));

        assertNotEq(0, panopticon.tokenHash(1));
        assertNotEq(panopticon.tokenHash(1), panopticon.tokenHash(2));
    }

    function testMintNoDuplicateTokenHashes() public {
        Panopticon collection = new Panopticon(1000, 0, address(0));
        collection.setMinter(address(this));

        for (uint256 i = 0; i < 1000; i++) {
            collection.mint(address(this));
            _usedHashes[collection.tokenHash(i)]++;

            // No hash can be used twice
            assertEq(_usedHashes[collection.tokenHash(i)], 1);
        }
    }

    function testINFT() public {
        assertEq(TEST_MAX_SUPPLY, panopticon.tokenIdMax());
        assertEq(0, panopticon.currentTokenId());

        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        panopticon.mint(address(this));

        assertNotEq(0, panopticon.tokenHash(1));
        assertNotEq(panopticon.tokenHash(1), panopticon.tokenHash(2));
        assertEq(2, panopticon.currentTokenId());
        assertEq(2, panopticon.totalSupply());
        uint16 available = panopticon.tokenIdMax() - panopticon.currentTokenId();
        assertEq(1, available);
    }

    function testMintReserve() public {
        panopticon.mintReserve(address(this), 1);
    }

    function testMintReserveNotOwner(address caller) public {
        vm.assume(caller != panopticon.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        panopticon.mintReserve(address(this), 1);
    }

    function testMintReserveNotEnoughReserveLeft() public {
        vm.expectRevert(NoSupplyLeft.selector);
        panopticon.mintReserve(address(this), TEST_RESERVE_MAX_SUPPLY + 1);
    }

    function testTokenHTML() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));

        string memory html = panopticon.tokenHTML(0);
        bytes memory output = bytes(html);
        assertEq(output[0], "<");
        assertEq(output[1], "h");
        assertEq(output[2], "t");
        assertEq(output[3], "m");
        assertEq(output[4], "l");
        assertEq(output[5], ">");
    }

    function testTokenURI() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));

        string memory metadata = panopticon.tokenURI(0);
        bytes memory output = bytes(metadata);
        assertEq(output[0], "d");
        assertEq(output[1], "a");
        assertEq(output[2], "t");
        assertEq(output[3], "a");
        assertEq(output[4], ":");
    }

    function testTokenURITokenNotFound() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));

        panopticon.tokenURI(0);
        vm.expectRevert(TokenNotFound.selector);
        panopticon.tokenURI(1);
    }

    function testTokenImageURI() public {
        panopticon.setMinter(address(this));
        panopticon.mint(address(this));

        string memory imageUri = panopticon.tokenImageURI(0);
        assertEq("https://api.example.com/images/0", imageUri);
    }

    function testTokenImageURITokenNotFound() public {
        vm.expectRevert(TokenNotFound.selector);
        panopticon.tokenImageURI(0);
    }

    function testTotalSupply() public {
        MockWallet randomRecipient = new MockWallet();

        // No mints, 0 supply
        assertEq(0, panopticon.totalSupply());

        // 2 mints, 2 supply
        panopticon.setMinter(address(this));
        panopticon.mint(address(randomRecipient));
        panopticon.mint(address(randomRecipient));
        assertEq(2, panopticon.totalSupply());

        // Mint
        // Each one of them has an assigned and queryable owner not equal to the zero address
        assertNotEq(address(0), panopticon.ownerOf(0));
        assertNotEq(address(1), panopticon.ownerOf(0));
    }

    function testTokenByIndex(uint256 _index) public {
        vm.assume(_index < 2);

        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        panopticon.mint(address(this));

        assertEq(_index, panopticon.tokenByIndex(_index), "token index is always the same as its ID");
    }

    function testTokenByIndexThrowIfIndexOverTotalSupply(uint256 overflowAmount) public {
        vm.assume(overflowAmount < 100000);

        panopticon.setMinter(address(this));
        panopticon.mint(address(this));
        uint256 totalSupply = panopticon.totalSupply();
        uint256 overflowingIndex = totalSupply + overflowAmount;

        assertEq(0, panopticon.tokenByIndex(0));
        assertEq(panopticon.totalSupply() - 1, panopticon.tokenByIndex(totalSupply - 1));

        vm.expectRevert("ERC721Enumerable: global index out of bounds");
        panopticon.tokenByIndex(totalSupply);

        vm.expectRevert("ERC721Enumerable: global index out of bounds");
        panopticon.tokenByIndex(overflowingIndex);
    }

    function testTokenOfOwnerByIndex() public {
        Panopticon testNft = new Panopticon(
            5,
            0,
            address(mockRenderer)
        );
        MockWallet ownerA = new MockWallet();
        MockWallet ownerB = new MockWallet();

        testNft.setMinter(address(this));
        testNft.mint(address(ownerA));
        testNft.mint(address(ownerB));
        testNft.mint(address(ownerA));
        testNft.mint(address(ownerB));
        testNft.mint(address(ownerB));

        // Owner A has 2 NFTs:
        // [0] -> Token ID 0
        // [1] -> Token ID 2
        assertEq(testNft.tokenOfOwnerByIndex(address(ownerA), 0), 0);
        assertEq(testNft.tokenOfOwnerByIndex(address(ownerA), 1), 2);
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        panopticon.tokenOfOwnerByIndex(address(ownerA), 2);

        // Owner B has 3 NFTs:
        assertEq(testNft.tokenOfOwnerByIndex(address(ownerB), 0), 1);
        assertEq(testNft.tokenOfOwnerByIndex(address(ownerB), 1), 3);
        assertEq(testNft.tokenOfOwnerByIndex(address(ownerB), 2), 4);
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        panopticon.tokenOfOwnerByIndex(address(ownerB), 2);

        // Revert for others
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        panopticon.tokenOfOwnerByIndex(address(this), 0);
    }

    function testTokenOfOwnerGasProfiling() public {
        MockWallet wallet = new MockWallet();
        Panopticon testNft = new Panopticon(
            600,
            600,
            address(mockRenderer)
        );
        testNft.mintReserve(address(wallet), 600);

        uint256 startGasLeft = gasleft();
        uint256 lastTokenId = testNft.tokenOfOwnerByIndex(address(wallet), 599);
        uint256 gasUsed = startGasLeft - gasleft();

        assertEq(lastTokenId, 599);
        assertLt(gasUsed, 200000, "Dont allow more than 200k gas to be used in tokenOfOwnerByIndex");
    }

    function testMintGasProfiling() public {
        MockWallet wallet = new MockWallet();
        Panopticon testNft = new Panopticon(
            600,
            600,
            address(mockRenderer)
        );
        testNft.setMinter(address(this));

        uint256 startGasLeft = gasleft();
        for(uint256 i = 0; i < 600; i++) {
            testNft.mint(address(wallet));
        }
        uint256 gasUsed = startGasLeft - gasleft();

        // 25 gwei/unit * 1,500,000 units = 2,500,000 gwei = 0.00375 eth
        uint256 gweiPerMint = gasUsed * 25 / 600;
        assertLt(gweiPerMint, 1_500_000, "Average mint price must be below 0.00375eth with 25 gwei");
    }

    function testTokenOfOwnerByIndexRevertsIfZeroAddress() public {
        vm.expectRevert();
        panopticon.tokenOfOwnerByIndex(address(0), 0);
    }

    function testTokenOfOwnerByIndexRevertsIfOverflowsBalance() public {
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        panopticon.tokenOfOwnerByIndex(address(this), 0);
    }

    function testERC721Metadata() public {
        assertEq("Panopticon", panopticon.name());
        assertEq("PAN", panopticon.symbol());
    }

    function testSupportsInterface() public {
        assertTrue(panopticon.supportsInterface(INTERFACE_ERC165), "Implements ERC-165: Standard Interface Detection");
        assertTrue(panopticon.supportsInterface(INTERFACE_ERC721), "Implements ERC-721: Non-Fungible Token Standard");
        assertTrue(
            panopticon.supportsInterface(INTERFACE_ERC721_METADATA), "Implements ERC-721's optional metadata extension"
        );
        assertTrue(panopticon.supportsInterface(INTERFACE_ERC721_ENUMERABLE), "Implements ERC721Enumerable");
        assertFalse(panopticon.supportsInterface(INTERFACE_ERC1155), "Does not implement ERC-1155");
        assertFalse(
            panopticon.supportsInterface(INTERFACE_ERC721_TOKEN_RECEIVER), "Does not implement ERC721TokenReceiver"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TraitsWithRarity.sol";

contract TraitsWithRaritySmallIndexTest is Test, TraitsWithRarity {
    uint256 constant public RARITY_INDEX_SIZE = 100;
    constructor() TraitsWithRarity(100) {}

    function setUp() public {
        TraitValue[] storage values1 = _initTrait("TRAIT1", "Trait 1", 0);
        values1.push(TraitValue(95, "Common"));
        values1.push(TraitValue(5, "Rare"));

        TraitValue[] storage values2 = _initTrait("TRAIT2", "Trait 2", 16);
        values2.push(TraitValue(33, "Red"));
        values2.push(TraitValue(33, "Green"));
        values2.push(TraitValue(34, "Blue"));
    }

    function testTraitValueIndexOf(uint16 rarityIndexOffset) public {
        vm.assume(rarityIndexOffset < RARITY_INDEX_SIZE);

        uint256 index1 = traitValueIndexOf("TRAIT1", rarityIndexOffset);
        uint256 index2 = traitValueIndexOf("TRAIT2", rarityIndexOffset);

        assertLt(index1, 2, "Must match either trait value by index (0-1)");
        assertLt(index2, 3, "Must match one of 3 traits values by index (0-2)");
    }

    function testTraitValueIndexOfRarityOutOfBounds(uint16 outOfBoundsIndex) public {
        vm.assume(outOfBoundsIndex >= RARITY_INDEX_SIZE);

        vm.expectRevert("Rarity index out of bounds");
        traitValueIndexOf("TRAIT1", outOfBoundsIndex);
    }

    function testTraitValueIndexOfTraitNotFound(uint16 rarityIndexOffset) public {
        vm.assume(rarityIndexOffset < 100);

        vm.expectRevert("Trait not found");
        traitValueIndexOf("TRAIT3", rarityIndexOffset);
    }

    function testTraitRarityIndexOf(uint256 tokenHash) public {
        uint256 rarityIndex = traitRarityIndexOf("TRAIT2", tokenHash);

        assertLt(
            rarityIndex,
            RARITY_INDEX_SIZE,
            "Returned rarityIndex value must be within defined rarity index size"
        );
    }

    function testGetTraitAsERC721JsonProperty() public {
        string memory json = _getTraitAsERC721JsonProperty("TRAIT1", 0);

        assertEq("{\"trait_type\":\"Trait 1\",\"value\":\"Common\"}", json);
    }

    function testGetTrait(uint256 tokenHash) public {
        TokenTrait memory trait = getTrait("TRAIT2", tokenHash);
        bytes32 valueNameHash = keccak256(abi.encodePacked(trait.valueName));

        assertEq("TRAIT2", trait.traitKey);
        assertEq("Trait 2", trait.traitName);
        assertLt(trait.valueIndex, 3, "Trait value index must be within defined ones");
        assertLt(trait.rarityIndex, 100, "Rarity index must be within defined bounds");
        assertTrue(
            (valueNameHash == keccak256(abi.encodePacked("Red")))
                || (valueNameHash == keccak256(abi.encodePacked("Green")))
                || (valueNameHash == keccak256(abi.encodePacked("Blue")))
        );
    }

    function testGetTraitKeys() public {
        string[] memory keys = getTraitKeys();

        assertEq(2, keys.length, "A key per trait is returned");
        assertEq("TRAIT1", keys[0]);
        assertEq("TRAIT2", keys[1]);
    }
}

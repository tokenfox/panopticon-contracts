// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {PanopticonTraits} from "../src/PanopticonTraits.sol";
import "solady/utils/LibString.sol";

contract PanopticonTraitsTest is Test, PanopticonTraits {
    function testTraitValueIndexOfForPalettes(uint16 rarityOffset) public {
        uint256 metroIndex = traitValueIndexOf("R_PAL", rarityOffset % 300);
        uint256 afterMetroIndex = traitValueIndexOf("R_PAL", 300 + rarityOffset % 700);
        uint256 stormIndex = traitValueIndexOf("R_PAL", 985 + rarityOffset % 15);
        uint256 beforeStormIndex = traitValueIndexOf("R_PAL", 985 - 1 - rarityOffset % 10);

        assertEq(metroIndex, 0, "Only values 0-299 must assign Metro as palette");
        assertEq(stormIndex, 10, "Only values 984-999 must assign Storm as palette");
        assertGt(afterMetroIndex, 0);
        assertLt(beforeStormIndex, 10);
    }

    function testTestRarityIndexOf() public {
        uint256 valueIndex = traitRarityIndexOf("R_PAL", 0);

        assertEq(valueIndex, 0);
    }

    function testVerifyTraits() public {
        string[] memory traitKeys = getTraitKeys();
        for (uint256 i = 0; i < traitKeys.length; i++) {
            _verifyTrait(traitKeys[i]);
        }

        assertEq(11, traitKeys.length, "Panopticon must have 11 traits");
    }

    function _verifyTrait(string memory traitKey) internal {
        TraitValue[] storage traitValues = _traitValues[traitKey];
        uint256 raritySum = 0;

        for (uint256 i = 0; i < traitValues.length; i++) {
            raritySum += traitValues[i].rarity;
        }

        assertEq(raritySum, _rarityIndexSize, string.concat("Rarity index size mismatch for: ", traitKey));
    }

    function testGenerateJSON() public {
        string[] memory traitKeys = getTraitKeys();
        string memory traitsJson = "[";

        for (uint256 i = 0; i < traitKeys.length; i++) {
            string memory traitKey = traitKeys[i];
            TraitValue[] memory traitValues = _traitValues[traitKey];
            string memory traitValuesJson = "";

            for (uint256 j = 0; j < traitValues.length; j++) {
                TraitValue memory value = traitValues[j];
                traitValuesJson = string.concat(
                    traitValuesJson,
                    "{",
                    "\"name\": \"",
                    value.name,
                    "\",",
                    "\"rarity\": ",
                    LibString.toString(value.rarity),
                    "}",
                    j + 1 < traitValues.length ? "," : ""
                );
            }

            traitsJson = string.concat(
                traitsJson,
                "{",
                "\"key\": \"",
                traitKey,
                "\",",
                "\"name\": \"",
                _traitNames[traitKey],
                "\",",
                "\"values\": [",
                traitValuesJson,
                "]",
                "}",
                i + 1 < traitKeys.length ? "," : "",
                "\n"
            );
        }

        traitsJson = string.concat(traitsJson, "]");

        vm.writeFile("generated/traits.json", traitsJson);
    }
}

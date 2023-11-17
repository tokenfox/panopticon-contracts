// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "solady/utils/LibString.sol";
import "solady/utils/Base64.sol";
import "../src/PanopticonTraits.sol";
import "../src/IPanopticonRenderer.sol";

contract MockRenderer is IPanopticonRenderer {
    constructor() {}

    function getName(uint256 tokenId) public pure returns (string memory) {
        return string.concat("Token #", LibString.toString(tokenId));
    }

    function getImage(uint256 tokenId, uint256 /* tokenHash */ ) external pure returns (string memory) {
        return string.concat("https://api.example.com/images/", LibString.toString(tokenId));
    }

    function getHTML(uint256 tokenId, uint256 tokenHash) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<html><body><h1>", getName(tokenId), "</h1><h2>", LibString.toString(tokenHash), "</h2></body></html>"
            )
        );
    }

    function getMetadata(uint256 tokenId, uint256 tokenHash) external view returns (string memory) {
        return string(_getMetadata(tokenId, tokenHash));
    }

    function tokenURI(uint256 tokenId, uint256 tokenHash) external view override returns (string memory) {
        bytes memory metadata = _getMetadata(tokenId, tokenHash);
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(metadata)));
    }

    function _getMetadata(uint256 tokenId, uint256 tokenHash) internal view returns (bytes memory) {
        return abi.encodePacked(
            "{\"name\":\"",
            getName(tokenId),
            "\",",
            "\"description\":\"",
            description,
            " hash=",
            LibString.toString(tokenHash),
            "\"}"
        );
    }

    string public description = "(DESCRIPTION)";
}

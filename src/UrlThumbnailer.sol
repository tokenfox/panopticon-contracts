// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solady/utils/LibString.sol";
import "./IThumbnailer.sol";
import "./Freezable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract UrlThumbnailer is Freezable, IThumbnailer {
    string public prefix;
    string public suffix;

    constructor(string memory _prefix, string memory _suffix) {
        prefix = _prefix;
        suffix = _suffix;
    }

    function setConfig(string memory _prefix, string memory _suffix) external onlyOwner notFrozen {
        prefix = _prefix;
        suffix = _suffix;
    }

    function getThumbnailUrl(uint256 tokenId) external view override returns (bytes memory) {
        return abi.encodePacked(prefix, LibString.toString(tokenId), suffix);
    }
}

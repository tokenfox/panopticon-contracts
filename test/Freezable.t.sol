// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Freezable.sol";

contract FreezableExample is Freezable {
    string public content;

    function setContent(string memory _content) external onlyOwner notFrozen {
        content = _content;
    }
}

contract FreezableTest is Test, Freezable {
    FreezableExample public instance;

    function setUp() public {
        instance = new FreezableExample();
    }

    function testSetContentWhenNotFrozen() public {
        instance.setContent("new");

        assertEq(instance.content(), "new");
    }

    function testSetContentRevertsAfterFreeze() public {
        instance.setContent("old");
        instance.freeze();
        vm.expectRevert(Frozen.selector);
        instance.setContent("new");

        assertEq(instance.content(), "old");
    }

    function testFreezeOnlyOwnerCanCall(address caller) public {
        vm.assume(caller != instance.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        instance.freeze();
    }

    function testFreezeRepeatedCallsRevert() public {
        instance.freeze();
        vm.expectRevert(Frozen.selector);
        instance.freeze();
    }

    function testExampleMethodOnlyOwnerCanCall(address caller) public {
        vm.assume(caller != instance.owner());
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        instance.setContent("unauthorized");
    }
}

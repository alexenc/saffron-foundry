// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract TimeWarper is Test {
    uint256 public constant MIN_WARP = 2 minutes;
    uint256 public constant MAX_WARP = 3 days;

    function warpTime(uint256 _warpAmount) public {
        uint256 boundedWarp = bound(_warpAmount, MIN_WARP, MAX_WARP);
        vm.warp(block.timestamp + boundedWarp);
    }
}

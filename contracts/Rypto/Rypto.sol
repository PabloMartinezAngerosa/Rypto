// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

import "hardhat/console.sol";

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Rypto {
        constructor() {
            console.log("Hello World by Rypto!:", msg.sender);
        }
}
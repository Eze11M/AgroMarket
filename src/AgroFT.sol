// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AgroFT is ERC20 {
    constructor(uint256 _initialSupply, address _treasury) ERC20 ("AgroFT", "AFT") {
        _mint(_treasury, _initialSupply * 10**decimals());
    }
}
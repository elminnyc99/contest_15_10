// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../../AlchemistV3.sol";

contract AlchemistHandler is CommonBase, StdCheats, StdUtils{
    AlchemistV3 private _alchemist;

    constructor(AlchemistV3 alchemist) {
        _alchemist = alchemist;
    }

    // TODO: Bind amounts to each function and randomly select a yield token for deposits and withdraw

    function deposit(uint256 amount) public {
        _alchemist.deposit(address(this), amount, address(this));
    }

    function withdraw(uint256 amount) public {
        _alchemist.withdraw(amount, address(this));
    }

    function mint(uint256 amount) public {
        _alchemist.mint(amount, address(this));
    }

    function repay(uint256 amount) public {
        _alchemist.repay(amount, address(this));
    }

    function liquidate() public {
        _alchemist.liquidate(address(this));
    }
}
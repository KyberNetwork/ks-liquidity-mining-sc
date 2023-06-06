// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract KyberSwapFarmingToken is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    AccessControl
{
    error InvalidOperation();

    // keccak256("OPERATOR") : 0x523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c
    bytes32 internal constant OPERATOR_ROLE =
        0x523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c;

    mapping(address => bool) public isWhitelist;

    constructor(
        address owner
    )
        ERC20("KyberSwapFarmingToken", "KS-FT")
        ERC20Permit("KyberSwapFarmingToken")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    function mint(
        address account,
        uint256 amount
    ) public onlyRole(OPERATOR_ROLE) {
        _mint(account, amount);
    }

    function burn(
        address account,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) {
        _burn(account, amount);
    }

    function addWhitelist(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isWhitelist[account] = true;
    }

    function removeWhitelist(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isWhitelist[account] = false;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (!isWhitelist[msg.sender] && !isWhitelist[recipient])
            revert InvalidOperation();
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (!isWhitelist[sender] && !isWhitelist[recipient])
            revert InvalidOperation();
        return super.transferFrom(sender, recipient, amount);
    }
}

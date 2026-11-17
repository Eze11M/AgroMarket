// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AgroNFT is ERC721, Ownable {
    address public orchestrator;
    uint256 private _counterIds;

    constructor() ERC721("AgroNFT", "ANFT") Ownable(msg.sender) {}

    function _update(address _to, uint256 _tokenId, address _auth) internal override returns (address) {
        require(msg.sender == orchestrator, "Only Official Orchestrator is authorized");

        return super._update(_to, _tokenId, _auth);
    }

    // SETTERS
    function changeOrchestrator(address _newOrchestrator) external onlyOwner {
        orchestrator = _newOrchestrator;
    }

    // MARKET FUNCTIONS
    function mint(address _account) external returns (uint256) {
        _counterIds++;
        uint256 nextId = _counterIds;
        _mint(_account, nextId);
        return nextId;
    }

    function burn(uint256 _tokenId) external {
        _burn(_tokenId);
    }
}
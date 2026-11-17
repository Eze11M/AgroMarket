// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgroNFT.sol";
import "./AgroFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AgroMKT is Ownable {
    AgroFT public agroFT;
    AgroNFT public agroNFT;

    address public treasury;
    uint256 public amountCollected;
    uint256 public collectCeiling;

    uint256 public buyFee = 200;
    uint256 public tradeFee = 100;

    bool public canBuy = true;
    bool public canTrade = true;
    bool public canClaim = false;

    uint16 public maxBatch = 10;
    uint32 public profit = 500;

    mapping(uint256 => bool) public tiers;
    mapping(uint256 => uint256) public values;

    struct Offer {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Offer) public market;

    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value);
    event Sale(uint256 indexed tokenId, uint256 value);
    event Trade(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 value);
    event Claim(address indexed claimer, uint256 indexed tokenId);

    constructor(
        address _token,
        address _nft,
        address _treasury,
        uint256 _ceiling
    ) Ownable(msg.sender) {
        require(_token != address(0), "Token cannot be zero address");
        require(_nft != address(0), "NFT cannot be zero address");
        require(_treasury != address(0), "Treasury cannot be zero address");
        require(_ceiling > 0, "Ceiling cannot be zero");
        agroFT = AgroFT(_token);
        agroNFT = AgroNFT(_nft);
        treasury = _treasury;
        collectCeiling = _ceiling;
    }

    function buyNextNFT(uint256 _value, uint256 _amount) external {
        require(canBuy, "NFT adquisition closed");
        require(_amount > 0 && _amount <= maxBatch, "NFT amount out of limits");
        require(tiers[_value], "NFT tier not valid");

        uint256 price = _value * _amount;
        require(amountCollected + price <= collectCeiling, "Reached market ceiling");

        uint256 fee = (price * buyFee) / 10000;
        uint256 totalPrice = price + fee;

        agroFT.transferFrom(msg.sender, treasury, totalPrice);
        
        amountCollected += price;
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = agroNFT.mint(msg.sender);
            values[tokenId] = _value;

            emit Buy(msg.sender, tokenId, _value);
        }
    }

    function saleNFT(uint256 _tokenId, uint256 _price) external {
        require(canTrade, "NFT trade closed");
        require(agroNFT.ownerOf(_tokenId) == msg.sender, "Not NFT owner");
        require(agroNFT.isApprovedForAll(msg.sender, address(this)), "Orchestrator not approved for all"); // Agregado por recomendación del profe
        require(_price > 0, "Price must not be zero");

        market[_tokenId] = Offer({
            seller: msg.sender,
            price: _price,
            active: true
        });

        emit Sale(_tokenId, _price);
    }

    function tradeNFT(uint256 _tokenId) external {
        require(canTrade, "NFT trade closed");
        Offer memory offer = market[_tokenId];
        require(offer.active, "NFT not on market");
        require(offer.seller != msg.sender, "Cannot buy NFT you own");

        uint256 fee = (offer.price * tradeFee) / 10000;
        uint256 sellerAmount = offer.price - fee;

        delete market[_tokenId];

        agroFT.transferFrom(msg.sender, treasury, fee);
        agroFT.transferFrom(msg.sender, offer.seller, sellerAmount);

        agroNFT.transferFrom(offer.seller, msg.sender, _tokenId);

        emit Trade(msg.sender, offer.seller, _tokenId, offer.price);
    }

    function claimNFT(uint256[] calldata _listTokenId) external {
        require(canClaim, "NFT claims closed");
        require(_listTokenId.length > 0 && _listTokenId.length <= maxBatch, "NFT amount out of limits");

        uint256 claimed = 0;

        for (uint256 i = 0; i < _listTokenId.length; i++) {
            uint256 tokenId = _listTokenId[i];
            require(agroNFT.ownerOf(tokenId) == msg.sender, "Not NFT owner");

            claimed += values[tokenId];
            delete values[tokenId];

            if (market[tokenId].active) {
                delete market[tokenId];
            }

            agroNFT.burn(tokenId);

            emit Claim(msg.sender, tokenId);
        }

        amountCollected -= claimed;
        uint256 claimTotal = claimed + ((claimed * profit) / 10000);

        agroFT.transferFrom(treasury, msg.sender, claimTotal);
    }

    // SETTERS
    function setTier(uint256 _value, bool _isValid) external onlyOwner {
        tiers[_value] = _isValid;
    }

    function setFees(uint256 _buyFee, uint256 _tradeFee) external onlyOwner {
        buyFee = _buyFee;
        tradeFee = _tradeFee;
    }

    function setProfit(uint32 _profit) external onlyOwner {
        profit = _profit;
    }

    function setState(bool _canBuy, bool _canTrade, bool _canClaim) external onlyOwner {
        canBuy = _canBuy;
        canTrade = _canTrade;
        canClaim = _canClaim;
    }

    function setCeiling(uint256 _ceiling) external onlyOwner {
        collectCeiling = _ceiling;
    }

    function setMaxBatch(uint16 _maxBatch) external onlyOwner {
        maxBatch = _maxBatch;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
    }
}
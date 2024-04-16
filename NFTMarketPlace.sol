// SPDX - License - Identifier : MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// Auction Contract
contract Auction {
    address payable public beneficiary ;
    
    uint256 public minimumBid ;
    address public maxBidder ;
    bool public auctionEnded ;

    constructor ( uint256 _minimumBid , address payable _beneficiaryAddress ) {
        minimumBid = _minimumBid ;
        beneficiary = _beneficiaryAddress ;
        maxBidder = address (0) ;
        auctionEnded = false ;
    }

    function bid () external payable {
        require ( msg . sender != maxBidder , " You are already the highest bidder .");
        require ( msg . value > minimumBid , " Bid amount too low .") ;
        require (! auctionEnded , " Auction has already ended .") ;

        if ( maxBidder != address (0) ) {
            payable ( maxBidder ).transfer( minimumBid ) ;
        }
        minimumBid = msg . value ;
        maxBidder = msg . sender ;
    }

    function settleAuction () external {
        require ( msg . sender == beneficiary , " Only beneficiary can settle the auction .");
        require (! auctionEnded , " Auction has already ended .") ;

        auctionEnded = true ;
        if ( maxBidder != address (0) ) {
            payable ( beneficiary ). transfer ( minimumBid );
        }
    }
}

contract NFTFactory is IERC721 {
    using Address for address;

    struct NFT {
        string name;
        string imageURL;
        address owner;
    }

    NFT[] public NFTArray;
    uint256 public NFTCounter;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor() {}

    function create(string memory _name, string memory _image_url) external {
        require(bytes(_name).length < 32, "Name too long");
        require(bytes(_image_url).length < 256, "Image URL too long");
        for (uint256 i = 0; i < NFTCounter; i++) {
            require(
                keccak256(bytes(_name)) != keccak256(bytes(NFTArray[i].name)) &&
                keccak256(bytes(_image_url)) != keccak256(bytes(NFTArray[i].imageURL)),
                "Name or image URL already exists"
            );
        }

        _mint(msg.sender, NFTCounter);
        NFTArray.push(NFT(_name, _image_url, msg.sender));
        NFTCounter++;
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _balances[to]++;
        _owners[tokenId] = to;
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        return _owners[tokenId];
    }

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || _operatorApprovals[owner][msg.sender], "ERC721: approve caller is not owner nor approved for all");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external override {
        revert();
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        revert();
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _owners[tokenId] = to;
        _balances[from]--;
        _balances[to]++;
        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
        revert();
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }
}

// MarketPlace Contract
contract MarketPlace is NFTFactory {
    mapping ( address => uint256 ) public ownerToAuctionId ;
    mapping ( uint256 => Auction ) public idToAuction ;
    mapping ( uint256 => uint256 ) public auctionToObject ;
    uint256 public auctionNumber ;

    function putForSale ( uint256 _minimumBid , uint256 assetId ) public {
        require(ownerOf(assetId) == msg.sender);

        Auction auction = new Auction(_minimumBid, payable(msg.sender));
        ownerToAuctionId[msg.sender] = auctionNumber;
        idToAuction[auctionNumber] = auction;
        auctionToObject[auctionNumber] = assetId;
        auctionNumber++;
    }

    function bid ( uint256 auctionId ) public {
        require(auctionId < auctionNumber);

        Auction auction = idToAuction[auctionNumber];
        auction.bid();
    }

    function settleAuction ( uint256 auctionId ) public {
        require(auctionId < auctionNumber);

        Auction auction = idToAuction[auctionId];
        auction.settleAuction();
        uint256 assetId = auctionToObject[auctionId];
        address highestBidder = auction.maxBidder();
        _transfer(highestBidder, msg.sender ,assetId);
    }
}
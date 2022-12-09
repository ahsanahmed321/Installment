//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract Platform {
    struct NFTDetail {
        uint256 nftId;
        address nftAddress;
        address seller;
        uint256 floorPrice;
        address buyer;
        uint256 installment;
        uint256 lastInstallmentDate;
        mapping(address => uint256) bids;
    }

    NFTDetail[] public nftDetails;

    mapping(bytes32 => uint256) public indexNftDetails;

    constructor() {
        // solhint-disable-previous-line no-empty-blocks
    }

    function openForBid(
        address _nft,
        uint256 _nftId,
        uint256 _floorPrice
    ) public {
        IERC721 nft = IERC721(_nft);
        nft.transferFrom(msg.sender, address(this), _nftId);

        NFTDetail storage newNFTDetail = nftDetails.push();

        newNFTDetail.nftId = _nftId;
        newNFTDetail.nftAddress = _nft;
        newNFTDetail.seller = payable(msg.sender);
        newNFTDetail.floorPrice = _floorPrice;

        indexNftDetails[keccak256(abi.encode(_nftId, _nft))] = nftDetails
            .length;
    }

    function placeBid(
        address _nft,
        uint256 _nftId,
        uint256 amount
    ) public payable {
        uint256 nftIndex = indexNftDetails[keccak256(abi.encode(_nftId, _nft))];
        NFTDetail storage nft = nftDetails[nftIndex];
        require(msg.value > (amount * 34) / 100, "34% should be paid upfront");
        require(amount > nft.floorPrice, "Bid is less than floor price");
        nft.bids[msg.sender] = amount;
    }

    function acceptBid(
        address _nft,
        uint256 _nftId,
        address _buyer
    ) public {
        uint256 nftIndex = indexNftDetails[keccak256(abi.encode(_nftId, _nft))];
        NFTDetail storage nft = nftDetails[nftIndex];
        require(nft.seller == msg.sender, "you dont own this nft");
        nft.buyer = _buyer;
        nft.installment = 1;
        nft.lastInstallmentDate = block.timestamp;
    }

    function payInstallment(address _nft, uint256 _nftId) public payable {
        uint256 nftIndex = indexNftDetails[keccak256(abi.encode(_nftId, _nft))];
        NFTDetail storage nft = nftDetails[nftIndex];
        require(nft.buyer == msg.sender, "you dont own this nft");
        require(
            msg.value > (nft.bids[msg.sender] * 33) / 100,
            "atleast 33% should be paid"
        );
        nft.installment += 1;
        nft.lastInstallmentDate = nft.installment + 30 days;

        if (nft.installment == 2) {
            payable(nft.seller).transfer((nft.bids[nft.buyer] * 34) / 100);
        }
        if (nft.installment == 3) {
            IERC721 nftInstance = IERC721(_nft);
            nftInstance.transferFrom(address(this), msg.sender, _nftId);

            payable(nft.seller).transfer((nft.bids[nft.buyer] * 66) / 100);
        }
    }

    function liquidateInstallment(address _nft, uint256 _nftId) public {
        uint256 nftIndex = indexNftDetails[keccak256(abi.encode(_nftId, _nft))];
        NFTDetail storage nft = nftDetails[nftIndex];
        if (
            nft.lastInstallmentDate + 30 days < block.timestamp &&
            nft.installment != 3
        ) {
            IERC721 nftContract = IERC721(_nft);
            nftContract.transferFrom(address(this), nft.seller, _nftId);

            if (nft.installment == 1) {
                payable(nft.seller).transfer((nft.bids[nft.buyer] * 33) / 100);
            }
            if (nft.installment == 2) {
                payable(nft.buyer).transfer((nft.bids[nft.buyer] * 33) / 100);
            }
        }
    }
}

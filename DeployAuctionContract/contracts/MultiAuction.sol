// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiAuction {
    struct Auction {
        address payable owner;
        uint startTime;
        uint endTime;
        uint highestBid;
        address highestBidder;
        bool ended;
        AuctionType auctionType;
        uint startPrice; // Used for Dutch Auction
        uint priceDecrement; // Used for Dutch Auction
        mapping(address => uint) bids; // Used for Sealed-Bid Auction
        bool revealed; // Used for Sealed-Bid Auction
    }

    enum AuctionType { English, Dutch, SealedBid }

    mapping(uint => Auction) public auctions;
    uint public auctionCount;
    mapping(address => uint) public pendingWithdrawals; // Withdrawal pattern to prevent reentrancy

    event AuctionCreated(uint auctionId, AuctionType auctionType, uint startPrice, uint endTime);
    event NewBid(uint auctionId, address bidder, uint bid, uint newPrice);
    event AuctionEnded(uint auctionId, address winner, uint winningBid);

    modifier onlyOwner(uint _auctionId) {
        require(msg.sender == auctions[_auctionId].owner, "Not the auction owner.");
        _;
    }

    function createAuction(AuctionType _type, uint _startPrice, uint _endTime, uint _priceDecrement) public {
        require(_endTime > block.timestamp, "End time must be in the future.");

        Auction storage newAuction = auctions[auctionCount];
        newAuction.owner = payable(msg.sender);
        newAuction.startTime = block.timestamp;
        newAuction.endTime = _endTime;
        newAuction.auctionType = _type;
        newAuction.startPrice = _startPrice;
        newAuction.priceDecrement = _priceDecrement;
        
        emit AuctionCreated(auctionCount, _type, _startPrice, _endTime);

        auctionCount++; // Increment after setting up the auction
    }

    function placeBid(uint _auctionId) public payable {
        Auction storage auction = auctions[_auctionId];
        require(!auction.ended, "Auction has already ended.");
        require(block.timestamp < auction.endTime, "Auction has already ended.");
        
        uint currentPrice = getCurrentPrice(_auctionId);
        require(msg.value >= currentPrice, "Bid is too low.");

        if (auction.auctionType == AuctionType.English) {
            require(msg.value > auction.highestBid, "There is already a higher bid.");

            // Refund previous highest bidder using withdrawal pattern
            if (auction.highestBidder != address(0)) {
                pendingWithdrawals[auction.highestBidder] += auction.highestBid;
            }

            auction.highestBid = msg.value;
            auction.highestBidder = msg.sender;

            // Extend auction time if the bid is placed near the end
            if (block.timestamp > auction.endTime - 5 minutes) {
                auction.endTime += 5 minutes;
            }

        } else if (auction.auctionType == AuctionType.Dutch) {
            auction.ended = true;
            auction.highestBid = msg.value;
            auction.highestBidder = msg.sender;
        } else {
            // For Sealed-Bid auction, accumulate bids
            auction.bids[msg.sender] += msg.value;
        }

        emit NewBid(_auctionId, msg.sender, msg.value, currentPrice);
    }

    function getCurrentPrice(uint _auctionId) public view returns (uint) {
        Auction storage auction = auctions[_auctionId];
        if (auction.auctionType == AuctionType.Dutch) {
            uint timeElapsed = block.timestamp - auction.startTime;
            uint priceDecrements = timeElapsed / 1 minutes;
            uint currentPrice = auction.startPrice - (priceDecrements * auction.priceDecrement);
            return currentPrice > 0 ? currentPrice : 0;
        } else {
            return auction.highestBid;
        }
    }

    function endAuction(uint _auctionId) public onlyOwner(_auctionId) {
        Auction storage auction = auctions[_auctionId];
        require(!auction.ended, "Auction already ended.");
        require(block.timestamp >= auction.endTime, "Auction not yet ended.");
        
        if (auction.auctionType == AuctionType.SealedBid) {
            require(!auction.revealed, "Bids already revealed.");
            auction.revealed = true;
            _revealSealedBids(_auctionId);
        } else {
            auction.ended = true;
            auction.owner.transfer(auction.highestBid);
        }

        emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
    }

    // Reveal the winner for Sealed-Bid auctions
    function _revealSealedBids(uint _auctionId) internal {
        Auction storage auction = auctions[_auctionId];
        uint highestBid;
        address highestBidder;

        // Check all bids and select the highest one
        for (uint i = 0; i < auctionCount; i++) {
            if (auction.bids[auction.highestBidder] > highestBid) {
                highestBid = auction.bids[auction.highestBidder];
                highestBidder = auction.highestBidder;
            }
        }
        
        auction.highestBid = highestBid;
        auction.highestBidder = highestBidder;
        auction.owner.transfer(auction.highestBid);
    }

    // Allow users to withdraw their bids
    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw.");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed.");
    }
}
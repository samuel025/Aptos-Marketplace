// TODO# 1: Define Module and Marketplace Address
address 0xfc60eccf7d6582b93e1f7e065726f1276f6e6a34200de5622218c0cb9d9c1a70 {

    module NFTMarketplace {
        use 0x1::signer;
        use 0x1::vector;
        use 0x1::coin;
        use 0x1::aptos_coin;
        use 0x1::event; // Import the event module

        // TODO# 2: Define NFT Structure
        struct NFT has store, key {
            id: u64,
            owner: address,
            creator: address,
            name: vector<u8>,
            description: vector<u8>,
            uri: vector<u8>,
            price: u64,
            for_sale: bool,
            rarity: u8  // 1 for common, 2 for rare, 3 for epic, etc.
        }

        // TODO# 3: Define Marketplace Structure
        struct Marketplace has key {
            nfts: vector<NFT>
        }
        
        //* TODO# 4: Define ListedNFT Structure
        struct ListedNFT has copy, drop {
            id: u64,
            price: u64,
            rarity: u8
        }

        // TODO# 5: Set Marketplace Fee
        const MARKETPLACE_FEE_PERCENT: u64 = 2; // 2% fee

        // Event definitions
        struct AuctionStarted has store {
            nft_id: u64,
            owner: address,
            end_time: u64
        }

        struct BidPlaced has store {
            nft_id: u64,
            bidder: address,
            bid_amount: u64
        }

        struct AuctionEnded has store {
            nft_id: u64,
            winner: address,
            final_bid: u64
        }

        // Add this constant for the minting fee
        const MINT_FEE: u64 = 100000000; // 1 APT = 100000000 octas

        // TODO# 6: Initialize Marketplace        
        public entry fun initialize(account: &signer) {
            let marketplace = Marketplace {
                nfts: vector::empty<NFT>()
            };
            move_to(account, marketplace);
        }

        // TODO# 7: Check Marketplace Initialization
         #[view]
        public fun is_marketplace_initialized(marketplace_addr: address): bool {
            exists<Marketplace>(marketplace_addr)
        }

        // TODO# 8: Mint New NFT
        public entry fun mint_nft(
            account: &signer,
            marketplace_addr: address,
            name: vector<u8>,
            description: vector<u8>,
            uri: vector<u8>,
            rarity: u8
        ) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            
            // Collect minting fee
            coin::transfer<aptos_coin::AptosCoin>(
                account,
                marketplace_addr, // Fee goes to marketplace
                MINT_FEE
            );

            let nft_id = vector::length(&marketplace.nfts);
            let creator_address = signer::address_of(account);

            let new_nft = NFT {
                id: nft_id,
                owner: creator_address,
                creator: creator_address,
                name,
                description,
                uri,
                price: 0,
                for_sale: false,
                rarity
            };

            vector::push_back(&mut marketplace.nfts, new_nft);

            // Emit NFT Minted event
            event::emit<NFTMinted>(NFTMinted {
                nft_id,
                creator: creator_address,
                rarity
            });
        }

        // Add a new event struct for minting
        struct NFTMinted has store {
            nft_id: u64,
            creator: address,
            rarity: u8
        }

        // TODO# 9: View NFT Details
        #[view]
        public fun get_nft_details(marketplace_addr: address, nft_id: u64): (u64, address, vector<u8>, vector<u8>, vector<u8>, u64, bool, u8) acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft = vector::borrow(&marketplace.nfts, nft_id);

            (nft.id, nft.owner, nft.name, nft.description, nft.uri, nft.price, nft.for_sale, nft.rarity)
        }
        
        // TODO# 10: List NFT for Sale
          public entry fun list_for_sale(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 100); // Caller is not the owner
            assert!(!nft_ref.for_sale, 101); // NFT is already listed
            assert!(price > 0, 102); // Invalid price

            nft_ref.for_sale = true;
            nft_ref.price = price;
        }

        // TODO# 11: Update NFT Price
           public entry fun set_price(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 200); // Caller is not the owner
            assert!(price > 0, 201); // Invalid price

            nft_ref.price = price;
        }

        // TODO# 12: Purchase NFT
         public entry fun purchase_nft(account: &signer, marketplace_addr: address, nft_id: u64, payment: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.for_sale, 400); // NFT is not for sale
            assert!(payment >= nft_ref.price, 401); // Insufficient payment

            // Calculate marketplace fee
            let fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100;
            let seller_revenue = payment - fee;

            // Transfer payment to the seller and fee to the marketplace
            coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, seller_revenue);
            coin::transfer<aptos_coin::AptosCoin>(account, signer::address_of(account), fee);

            // Transfer ownership
            nft_ref.owner = signer::address_of(account);
            nft_ref.for_sale = false;
            nft_ref.price = 0;
        }

        // TODO# 13: Check if NFT is for Sale
         #[view]
        public fun is_nft_for_sale(marketplace_addr: address, nft_id: u64): bool acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft = vector::borrow(&marketplace.nfts, nft_id);
            nft.for_sale
        }

        // TODO# 14: Get NFT Price
         #[view]
        public fun get_nft_price(marketplace_addr: address, nft_id: u64): u64 acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft = vector::borrow(&marketplace.nfts, nft_id);
            nft.price
        }

        // TODO# 15: Transfer Ownership
        public entry fun transfer_ownership(account: &signer, marketplace_addr: address, nft_id: u64, new_owner: address) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 300); // Caller is not the owner
            assert!(nft_ref.owner != new_owner, 301); // Prevent transfer to the same owner

            // Update NFT ownership and reset its for_sale status and price
            nft_ref.owner = new_owner;
            nft_ref.for_sale = false;
            nft_ref.price = 0;
        }

        // TODO# 16: Retrieve NFT Owner
        #[view]
        public fun get_owner(marketplace_addr: address, nft_id: u64): address acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft = vector::borrow(&marketplace.nfts, nft_id);
            nft.owner
        }

        // TODO# 17: Retrieve NFTs for Sale
         #[view]
        public fun get_all_nfts_for_owner(marketplace_addr: address, owner_addr: address, limit: u64, offset: u64): vector<u64> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft_ids = vector::empty<u64>();

            let nfts_len = vector::length(&marketplace.nfts);
            let end = min(offset + limit, nfts_len);
            let mut_i = offset;
            while (mut_i < end) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.owner == owner_addr) {
                    vector::push_back(&mut nft_ids, nft.id);
                };
                mut_i = mut_i + 1;
            };

            nft_ids
        }

        // TODO# 18: Retrieve NFTs for Sale
         #[view]
        public fun get_all_nfts_for_sale(marketplace_addr: address, limit: u64, offset: u64): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nfts_for_sale = vector::empty<ListedNFT>();

            let nfts_len = vector::length(&marketplace.nfts);
            let end = min(offset + limit, nfts_len);
            let mut_i = offset;
            while (mut_i < end) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.for_sale) {
                    let listed_nft = ListedNFT { id: nft.id, price: nft.price, rarity: nft.rarity };
                    vector::push_back(&mut nfts_for_sale, listed_nft);
                };
                mut_i = mut_i + 1;
            };

            nfts_for_sale
        }

        // TODO# 19: Define Helper Function for Minimum Value
         // Helper function to find the minimum of two u64 numbers
        public fun min(a: u64, b: u64): u64 {
            if (a < b) { a } else { b }
        }

        // TODO# 20: Retrieve NFTs by Rarity
         // New function to retrieve NFTs by rarity
        #[view]
        public fun get_nfts_by_rarity(marketplace_addr: address, rarity: u8): vector<u64> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft_ids = vector::empty<u64>();

            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = 0;
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.rarity == rarity) {
                    vector::push_back(&mut nft_ids, nft.id);
                };
                mut_i = mut_i + 1;
            };

            nft_ids
        }

        // TODO# 21: Define Auction Structure
        struct Auction has key {
            nft_id: u64,
            highest_bid: u64,
            highest_bidder: address,
            end_time: u64,
            is_active: bool
        }

        // TODO# 22: Start Auction
        public entry fun start_auction(account: &signer, marketplace_addr: address, nft_id: u64, duration: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 500); // Caller is not the owner
            assert!(!nft_ref.for_sale, 501); // NFT is already listed for sale

            let auction = Auction {
                nft_id,
                highest_bid: 0,
                highest_bidder: address::zero(),
                end_time: timestamp::now_seconds() + duration,
                is_active: true
            };

            move_to(account, auction);
            nft_ref.for_sale = false; // Mark NFT as not for sale

            // Emit Auction Started Event
            event::emit<AuctionStarted>(AuctionStarted {
                nft_id,
                owner: signer::address_of(account),
                end_time: auction.end_time
            });
        }

        // TODO# 23: Place Bid
        public entry fun place_bid(account: &signer, marketplace_addr: address, nft_id: u64, bid_amount: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let auction = borrow_global_mut<Auction>(signer::address_of(account));

            assert!(auction.is_active, 600); // Auction is not active
            assert!(timestamp::now_seconds() < auction.end_time, 601); // Auction has ended
            assert!(bid_amount > auction.highest_bid, 602); // Bid must be higher than current highest bid

            // Transfer payment to the previous highest bidder if applicable
            if (auction.highest_bidder != address::zero()) {
                coin::transfer<aptos_coin::AptosCoin>(account, auction.highest_bidder, auction.highest_bid);
            }

            auction.highest_bid = bid_amount;
            auction.highest_bidder = signer::address_of(account);

            // Emit Bid Placed Event
            event::emit<BidPlaced>(BidPlaced {
                nft_id,
                bidder: signer::address_of(account),
                bid_amount
            });
        }

        // TODO# 24: End Auction
        public entry fun end_auction(account: &signer, marketplace_addr: address, nft_id: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let auction = borrow_global_mut<Auction>(signer::address_of(account));

            assert!(auction.is_active, 700); // Auction is not active
            assert!(timestamp::now_seconds() >= auction.end_time, 701); // Auction has not ended

            auction.is_active = false;

            if (auction.highest_bidder != address::zero()) {
                let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);
                nft_ref.owner = auction.highest_bidder; // Transfer ownership to the highest bidder
                nft_ref.for_sale = false; // Mark NFT as not for sale
                nft_ref.price = 0; // Reset price

                // Emit Auction Ended Event
                event::emit<AuctionEnded>(AuctionEnded {
                    nft_id,
                    winner: auction.highest_bidder,
                    final_bid: auction.highest_bid
                });
            }
        }

        // TODO# 25: Implement Royalties on Secondary Sales
        public entry fun sell_nft_with_royalty(account: &signer, marketplace_addr: address, nft_id: u64, sale_price: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 800); // Caller is not the owner
            assert!(sale_price > 0, 801); // Invalid sale price

            // Calculate royalty
            let royalty = (sale_price * MARKETPLACE_FEE_PERCENT) / 100;
            let seller_revenue = sale_price - royalty;

            // Transfer payment to the seller and royalty to the creator
            coin::transfer<aptos_coin::AptosCoin>(account, signer::address_of(account), seller_revenue);
            coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.creator, royalty); // Send royalty to the original creator

            // Transfer ownership
            nft_ref.owner = signer::address_of(account);
            nft_ref.for_sale = false; // Mark NFT as not for sale
            nft_ref.price = 0; // Reset price
        }

        // Add a function to check the minting fee
        #[view]
        public fun get_mint_fee(): u64 {
            MINT_FEE
        }

        // TODO# 26: Advanced Filtering and Sorting Functions
        public fun get_nfts_by_price_range(
            marketplace_addr: address,
            min_price: u64,
            max_price: u64
        ): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let filtered_nfts = vector::empty<ListedNFT>();

            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = 0;
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.for_sale && nft.price >= min_price && nft.price <= max_price) {
                    let listed_nft = ListedNFT {
                        id: nft.id,
                        price: nft.price,
                        rarity: nft.rarity
                    };
                    vector::push_back(&mut filtered_nfts, listed_nft);
                };
                mut_i = mut_i + 1;
            };

            filtered_nfts
        }

        // Get NFTs by multiple filters
        public fun get_nfts_filtered(
            marketplace_addr: address,
            min_price: u64,
            max_price: u64,
            rarity: u8,
            sort_by_price: bool,
            ascending: bool
        ): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let filtered_nfts = vector::empty<ListedNFT>();

            // First, collect all NFTs that match the criteria
            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = 0;
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.for_sale && 
                    nft.price >= min_price && 
                    nft.price <= max_price &&
                    nft.rarity == rarity) {
                    let listed_nft = ListedNFT {
                        id: nft.id,
                        price: nft.price,
                        rarity: nft.rarity
                    };
                    vector::push_back(&mut filtered_nfts, listed_nft);
                };
                mut_i = mut_i + 1;
            };

            // Sort the results if requested
            if (sort_by_price) {
                sort_nfts_by_price(&mut filtered_nfts, ascending);
            };

            filtered_nfts
        }

        // Helper function to sort NFTs by price
        fun sort_nfts_by_price(nfts: &mut vector<ListedNFT>, ascending: bool) {
            let len = vector::length(nfts);
            let i = 0;
            while (i < len) {
                let j = 0;
                while (j < len - i - 1) {
                    let nft1 = vector::borrow(nfts, j);
                    let nft2 = vector::borrow(nfts, j + 1);
                    
                    if (ascending) {
                        if (nft1.price > nft2.price) {
                            vector::swap(nfts, j, j + 1);
                        };
                    } else {
                        if (nft1.price < nft2.price) {
                            vector::swap(nfts, j, j + 1);
                        };
                    };
                    j = j + 1;
                };
                i = i + 1;
            };
        }

        // Get recently listed NFTs
        public fun get_recently_listed_nfts(
            marketplace_addr: address,
            limit: u64
        ): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let listed_nfts = vector::empty<ListedNFT>();
            
            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = if (nfts_len > limit) { nfts_len - limit } else { 0 };
            
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.for_sale) {
                    vector::push_back(&mut listed_nfts, ListedNFT {
                        id: nft.id,
                        price: nft.price,
                        rarity: nft.rarity
                    });
                };
                mut_i = mut_i + 1;
            };

            listed_nfts
        }

        // TODO# 27: NFT Transfer Functions
        struct NFTTransferred has store {
            nft_id: u64,
            from: address,
            to: address,
            timestamp: u64
        }

        public entry fun transfer_nft(
            account: &signer,
            marketplace_addr: address,
            nft_id: u64,
            recipient: address
        ) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            // Verify ownership and not for sale
            assert!(nft_ref.owner == signer::address_of(account), 900); // Not the owner
            assert!(!nft_ref.for_sale, 901); // NFT is listed for sale
            assert!(recipient != nft_ref.owner, 902); // Cannot transfer to self

            // Update ownership
            let previous_owner = nft_ref.owner;
            nft_ref.owner = recipient;

            // Emit transfer event
            event::emit<NFTTransferred>(NFTTransferred {
                nft_id,
                from: previous_owner,
                to: recipient,
                timestamp: timestamp::now_seconds()
            });
        }

        // Batch transfer multiple NFTs
        public entry fun batch_transfer_nfts(
            account: &signer,
            marketplace_addr: address,
            nft_ids: vector<u64>,
            recipient: address
        ) acquires Marketplace {
            let i = 0;
            let len = vector::length(&nft_ids);
            
            while (i < len) {
                let nft_id = *vector::borrow(&nft_ids, i);
                transfer_nft(account, marketplace_addr, nft_id, recipient);
                i = i + 1;
            }
        }

        // Get all NFTs owned by an address with filters
        public fun get_owned_nfts_filtered(
            marketplace_addr: address,
            owner: address,
            rarity: u8,
            sort_by_price: bool
        ): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let filtered_nfts = vector::empty<ListedNFT>();

            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = 0;
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.owner == owner && nft.rarity == rarity) {
                    vector::push_back(&mut filtered_nfts, ListedNFT {
                        id: nft.id,
                        price: nft.price,
                        rarity: nft.rarity
                    });
                };
                mut_i = mut_i + 1;
            };

            if (sort_by_price) {
                sort_nfts_by_price(&mut filtered_nfts, true);
            };

            filtered_nfts
        }
    }
}

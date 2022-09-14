#[test_only]
module liquidswap::econia_tests {
    use std::signer;

    use econia::market;
    use econia::registry;
    use econia::user;
    use test_coin_admin::test_coins::{Self, BTC, USDT};

    /// Ask flag
    const ASK: bool = true;
    /// Bid flag
    const BID: bool = false;
    /// Buy direction flag
    const BUY: bool = true;
    /// `u64` bitmask with all bits set
    const HI_64: u64 = 0xffffffffffffffff;
    /// Custodian ID flag for no delegated custodian
    const NO_CUSTODIAN: u64 = 0;

    // Market parameters
    #[test_only]
    /// Market ID for first registered market
    const MARKET_ID: u64 = 0;
    #[test_only]
    /// Lot size for test market
    const LOT_SIZE: u64 = 10;
    #[test_only]
    /// Tick size for test market
    const TICK_SIZE: u64 = 25;
    #[test_only]
    /// Generic asset transfer custodian ID for test market
    const GENERIC_ASSET_TRANSFER_CUSTODIAN_ID: u64 = 1;

    // End-to-end testing user parameters
    #[test_only]
    const USER_0_GENERAL_CUSTODIAN_ID: u64 = 2;
    #[test_only]
    const USER_1_GENERAL_CUSTODIAN_ID: u64 = 3;
    #[test_only]
    const USER_2_GENERAL_CUSTODIAN_ID: u64 = 4;
    #[test_only]
    const USER_3_GENERAL_CUSTODIAN_ID: u64 = 5;
    #[test_only]
    const USER_0_START_BASE: u64 =  1000000000000;
    #[test_only]
    const USER_1_START_BASE: u64 =  2000000000000;
    #[test_only]
    const USER_2_START_BASE: u64 =  3000000000000;
    #[test_only]
    const USER_3_START_BASE: u64 =  4000000000000;
    #[test_only]
    const USER_0_START_QUOTE: u64 = 1500000000000;
    #[test_only]
    const USER_1_START_QUOTE: u64 = 2500000000000;
    #[test_only]
    const USER_2_START_QUOTE: u64 = 3500000000000;
    #[test_only]
    const USER_3_START_QUOTE: u64 = 4500000000000;
    #[test_only]
    const USER_1_ASK_PRICE: u64 = 10;
    #[test_only]
    const USER_2_ASK_PRICE: u64 = 11;
    #[test_only]
    const USER_3_ASK_PRICE: u64 = 12;
    #[test_only]
    const USER_1_BID_PRICE: u64 =  5;
    #[test_only]
    const USER_2_BID_PRICE: u64 =  4;
    #[test_only]
    const USER_3_BID_PRICE: u64 =  3;
    #[test_only]
    const USER_1_ASK_SIZE: u64 = 9;
    #[test_only]
    const USER_2_ASK_SIZE: u64 = 8;
    #[test_only]
    const USER_3_ASK_SIZE: u64 = 7;
    #[test_only]
    const USER_1_BID_SIZE: u64 = 3;
    #[test_only]
    const USER_2_BID_SIZE: u64 = 4;
    #[test_only]
    const USER_3_BID_SIZE: u64 = 5;
    #[test_only]
    const USER_1_COUNTER: u64 = 0;
    #[test_only]
    const USER_2_COUNTER: u64 = 1;
    #[test_only]
    const USER_3_COUNTER: u64 = 2;
    #[test_only]
    const USER_0_COUNTER: u64 = 3; // Placed after all others

    #[test_only]
    /// Return size and price for end-to-end orders on given `side`.
    fun get_end_to_end_orders_size_price_test(
        side: bool
    ) : (
        u64,
        u64,
        u64,
        u64,
        u64,
        u64
    ) {
        if (side == ASK) (
            USER_1_ASK_SIZE, USER_1_ASK_PRICE, USER_2_ASK_SIZE,
            USER_2_ASK_PRICE, USER_3_ASK_SIZE, USER_3_ASK_PRICE
        ) else (
            USER_1_BID_SIZE, USER_1_BID_PRICE, USER_2_BID_SIZE,
            USER_2_BID_PRICE, USER_3_BID_SIZE, USER_3_BID_PRICE
        )
    }

    #[test_only]
    /// Initialize a user with a funded market account.
    ///
    /// Inner function for `register_end_to_end_market_accounts_test()`.
    ///
    /// # Type parameters
    /// * `BaseType`: Base type for market
    /// * `QuoteType`: Quote type for market
    ///
    /// # Parameters
    /// * `econia`: Immutable reference to signature from Econia
    /// * `user`: Immutable reference to signature from user
    /// * `general_custodian_id`: User's general custodian ID, marked
    ///   `NO_CUSTODIAN`: if user does not have general custodian
    /// * `start_base`: Amount of base asset user starts with in market
    ///    account
    /// * `start_quote`: Amount of quote asset user starts with in
    ///   market account
    fun register_end_to_end_market_account_test<
        BaseType,
        QuoteType
    >(
        coin_admin: &signer,
        user: &signer,
        general_custodian_id: u64,
        start_base: u64,
        start_quote: u64
    ) {
        user::register_market_account<BaseType, QuoteType>(user, MARKET_ID,
            general_custodian_id); // Register market account
        register_end_to_end_market_account_deposit_test<BaseType>(coin_admin,
            user, general_custodian_id, start_base); // Deposit base
        register_end_to_end_market_account_deposit_test<QuoteType>(coin_admin,
            user, general_custodian_id, start_quote); // Deposit quote
    }

    #[test_only]
    /// Deposit specified amount of asset to user's market account
    ///
    /// Inner function for `register_end_to_end_market_account_test()`.
    ///
    /// # Type parameters
    /// * `AssetType`: Asset type to deposit
    ///
    /// # Parameters
    /// * `econia`: Immutable reference to signature from Econia
    /// * `user`: Immutable reference to signature from user
    /// * `general_custodian_id`: General custodian ID for user's market
    ///   account
    /// * `amount`: Amount to deposit
    fun register_end_to_end_market_account_deposit_test<
        AssetType
    >(
        coin_admin: &signer,
        user: &signer,
        general_custodian_id: u64,
        amount: u64
    ) {
        // Mint specified amount of coins

        let coins = test_coins::mint<AssetType>(coin_admin, amount);
        user::deposit_coins(signer::address_of(user), MARKET_ID,
            general_custodian_id, coins); // Deposit coins
    }

    #[test(
        econia = @econia,
        user_0 = @user_0,
        user_1 = @user_1,
        user_2 = @user_2,
        user_3 = @user_3,
    )]
    /// Swap buy coins
    fun test_end_to_end_swap_coins_buy(
        econia: &signer,
        user_0: &signer,
        user_1: &signer,
        user_2: &signer,
        user_3: &signer
    ) {
        // Assign test setup values
        let book_side = ASK;
        // Assign swap values
        let direction = BUY;
        let min_base = LOT_SIZE * (USER_1_ASK_SIZE + USER_2_ASK_SIZE);
        let max_base = min_base + 1000000;
        let min_quote = 0;
        let max_quote = TICK_SIZE * (USER_1_ASK_SIZE * USER_1_ASK_PRICE +
            USER_2_ASK_SIZE * USER_2_ASK_PRICE);
        let limit_price = USER_3_ASK_PRICE;

        // Register users with orders on the book
        let coin_admin = test_coins::create_admin_with_coins();
        registry::init_registry(econia); // Initialize registry
        // Set all potential custodian IDs as valid
        registry::set_registered_custodian_test(HI_64);
        // Register market accordingly
        market::register_market_pure_coin<BTC, USDT>(econia, LOT_SIZE, TICK_SIZE);

        register_end_to_end_market_account_test<BTC, USDT>(&coin_admin,
            user_0, NO_CUSTODIAN, USER_0_START_BASE,
            USER_0_START_QUOTE); // Register user 0's market account
        register_end_to_end_market_account_test<BTC, USDT>(&coin_admin,
            user_1, USER_1_GENERAL_CUSTODIAN_ID, USER_1_START_BASE,
            USER_1_START_QUOTE); // Register user 1's market account
        register_end_to_end_market_account_test<BTC, USDT>(&coin_admin,
            user_2, USER_2_GENERAL_CUSTODIAN_ID, USER_2_START_BASE,
            USER_2_START_QUOTE); // Register user 2's market account
        register_end_to_end_market_account_test<BTC, USDT>(&coin_admin,
            user_3, USER_3_GENERAL_CUSTODIAN_ID, USER_3_START_BASE,
            USER_3_START_QUOTE); // Register user 3's market account

        let (size_1, price_1, size_2, price_2, size_3, price_3) =
            get_end_to_end_orders_size_price_test(book_side);
        // Place limit orders for each user
        let user_1_custodian_capability = registry::get_custodian_capability_test(USER_1_GENERAL_CUSTODIAN_ID);
        market::place_limit_order_custodian<BTC, USDT>(@user_1, @econia, MARKET_ID, book_side, size_1, price_1,
            false, false, false, &user_1_custodian_capability);
        registry::destroy_custodian_capability_test(user_1_custodian_capability);

        let user_2_custodian_capability = registry::get_custodian_capability_test(USER_2_GENERAL_CUSTODIAN_ID);
        market::place_limit_order_custodian<BTC, USDT>(@user_2, @econia, MARKET_ID, book_side, size_2, price_2,
            false, false, false, &user_2_custodian_capability);
        registry::destroy_custodian_capability_test(user_2_custodian_capability);

        let user_3_custodian_capability = registry::get_custodian_capability_test(USER_3_GENERAL_CUSTODIAN_ID);
        market::place_limit_order_custodian<BTC, USDT>(@user_3, @econia, MARKET_ID, book_side, size_3, price_3,
            false, false, false, &user_3_custodian_capability
        );
        registry::destroy_custodian_capability_test(user_3_custodian_capability);

        let (base_coins, quote_coins) = (// Mint coins
            test_coins::mint<BTC>(&coin_admin, USER_0_START_BASE),
            test_coins::mint<USDT>(&coin_admin, USER_0_START_QUOTE),
        );
        // Swap coins, storing base and quote coins filled
        let (base_filled, quote_filled) = market::swap_coins(@econia, MARKET_ID,
            direction, min_base, max_base, min_quote, max_quote, limit_price,
            &mut base_coins, &mut quote_coins);
        // Assert coin swap return values
        assert!(base_filled == min_base, 0);
        assert!(quote_filled == max_quote, 1);
        // Verify state
        // Destroy coins
        test_coins::burn(&coin_admin, base_coins);
        test_coins::burn(&coin_admin, quote_coins);
    }
}

module liquidswap::gauge {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::iterable_table::{Self, IterableTable};

    use liquidswap::bribe::{Self, Bribe};
    use liquidswap::liquid::LAMM;
    use liquidswap::ve::{Self, VE_NFT};

    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    struct Gauge has store {
        bribe: Bribe,
        rewards: Coin<LAMM>,
        reward_rate: u64,
        period_finish: u64,
        total_voted: u64,
        voted_per_token: IterableTable<u64, u64>  // table<token_id, vote>
    }

    public(friend) fun vote(gauge: &mut Gauge, ve_nft: &VE_NFT, vote: u64) {
        let ve_token_id = ve::get_nft_id(ve_nft);
        let votes = iterable_table::borrow_mut_with_default(&mut gauge.voted_per_token, ve_token_id, 0);
        *votes = vote;

        gauge.total_voted = gauge.total_voted + vote;
    }

    public(friend) fun add_rewards(gauge: &mut Gauge, coin_in: Coin<LAMM>) {
        let coin_in_value = coin::value(&coin_in);
        let now = timestamp::now_seconds();
        if (now >= gauge.period_finish) {
            gauge.reward_rate = coin_in_value / WEEK;
        } else {
            let remaining = gauge.period_finish - now;
            let left = remaining * gauge.reward_rate;
            assert!(coin_in_value > left, 2);
            gauge.reward_rate = (coin_in_value + left) / WEEK;
        };

        coin::merge(&mut gauge.rewards, coin_in);

        assert!(gauge.reward_rate <= coin::value(&gauge.rewards) / WEEK, 3);
        gauge.period_finish = now + WEEK;
    }

    public(friend) fun withdraw_rewards(gauge: &mut Gauge, ve_nft: &VE_NFT): Coin<LAMM> {
        let ve_token_id = ve::get_nft_id(ve_nft);
        let token_votes = iterable_table::borrow(&gauge.voted_per_token, ve_token_id);

        let now = timestamp::now_seconds();
        let time = if (now >= gauge.period_finish) { WEEK } else { now + WEEK - gauge.period_finish };
        let amount = time * gauge.reward_rate * *token_votes / gauge.total_voted;
        assert!(amount <= coin::value(&gauge.rewards), 1);

        coin::extract(&mut gauge.rewards, amount)
    }

    public(friend) fun zero_gauge(): Gauge {
        Gauge {
            bribe: bribe::zero_bribe(),
            rewards: coin::zero(),
            reward_rate: 0,
            period_finish: 0,
            total_voted: 0,
            voted_per_token: iterable_table::new<u64, u64>()
        }
    }
}

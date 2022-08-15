module liquidswap::voter {

    use liquidswap::ve;

    struct VoterConfig has key {
        total_weight: u64,
    }

    public fun vote(nft: &mut ve::VE_NFT) {

    }
}

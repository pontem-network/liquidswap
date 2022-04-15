script {
    use AptosFramework::Genesis;

    fun genesis(core: signer) {
        Genesis::setup(&core);
    }
}

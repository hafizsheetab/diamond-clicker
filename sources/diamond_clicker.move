module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    /*
    Const
    DO NOT EDIT
    */
    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {
        move_to(account, GameStore {
            diamonds: 0,
            upgrades: vector::empty<Upgrade>(),
            last_claimed_timestamp_seconds: timestamp::now_seconds() ,
        });
    }

    public entry fun click(account: &signer) acquires GameStore {
        // check if GameStore does not exist - if not, initialize_game
        let account_address = signer::address_of(account);
        if(!exists<GameStore>(account_address)){
            initialize_game(account);
        };
        // increment game_store.diamonds by +1
        let diamonds = &mut borrow_global_mut<GameStore>(account_address).diamonds;
        *diamonds = *diamonds + 1;
    }
    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {
        // loop over game_store.upgrades - if the powerup exists then calculate the dpm and minutes_elapsed to add the amount to the unclaimed_diamonds
        let game_store = borrow_global<GameStore>(account_address);
        let minutes_elapsed:u64 = (current_timestamp_seconds - game_store.last_claimed_timestamp_seconds)/60;
        let dpm = get_diamonds_per_minute(account_address);
        let unclaimed_diamonds = dpm * minutes_elapsed;

        
        // return unclaimed_diamonds
        return unclaimed_diamonds
    }

    fun claim(account_address: address) acquires GameStore {
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::now_seconds());
        let game_store = borrow_global_mut<GameStore>(account_address);
        let diamonds = &mut game_store.diamonds;
        let last_claimed_timestamp_seconds = &mut game_store.last_claimed_timestamp_seconds;
        *diamonds = *diamonds + unclaimed_diamonds;
        *last_claimed_timestamp_seconds = timestamp::now_seconds();
        // set game_store.diamonds to current diamonds + unclaimed_diamonds
        // set last_claimed_timestamp_seconds to the current timestamp in seconds
    }

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
        let account_address = signer::address_of(account);
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // check that the game store exists
        // check the powerup_names length is greater than or equal to upgrade_index
        assert!(vector::length(&POWERUP_NAMES) > upgrade_index, ERROR_UPGRADE_DOES_NOT_EXIST);
        // claim for account address
        claim(account_address);
       
        let game_store = borrow_global_mut<GameStore>(account_address);
        let power_up_name = vector::borrow(&POWERUP_NAMES, upgrade_index);
        let power_up_value = vector::borrow(&POWERUP_VALUES, upgrade_index);
        let total_upgrade_cost = *vector::borrow(power_up_value, 0) * upgrade_amount;
         // check that the user has enough coins to make the current upgrade
        assert!(game_store.diamonds >= total_upgrade_cost, ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE);
        // loop through game_store upgrades - if the upgrade exists then increment but the upgrade_amount
        let upgrades_exists_flag = false;
        let upgrades_length = vector::length(&game_store.upgrades);
        let i = 0;
        while (i < upgrades_length){
            let upgrade_mut = vector::borrow_mut(&mut game_store.upgrades, i);
            i = i+1;
            if(upgrade_mut.name == *power_up_name){
                upgrades_exists_flag = true;
                let amount = &mut upgrade_mut.amount;
                *amount = *amount + upgrade_amount;
                break
            }

        };
        // if upgrade_existed does not exist then create it with the base upgrade_amount
        if(!upgrades_exists_flag){
            vector::push_back(&mut game_store.upgrades, Upgrade {
                name: *power_up_name,
                amount: upgrade_amount
            });
        };
        // set game_store.diamonds to current diamonds - total_upgrade_cost
        let diamonds = &mut game_store.diamonds;
        *diamonds = *diamonds - total_upgrade_cost;
    }

    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
        let game_store = borrow_global<GameStore>(account_address);
        return game_store.diamonds + get_unclaimed_diamonds(account_address,  timestamp::now_seconds())
    }

    #[view]
    public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {
        let game_store = borrow_global<GameStore>(account_address);
        let upgrades_length = vector::length(&game_store.upgrades);
        let i=0;
        let dpm: u64 = 0;
        while (i < upgrades_length){
            let upgrade = vector::borrow(&game_store.upgrades, i);
            let (upgrades_exist, upgrades_index) = vector::index_of(&POWERUP_NAMES, &upgrade.name);
            if(upgrades_exist){
                let power_up_value = vector::borrow(&POWERUP_VALUES, upgrades_index);
                dpm = dpm + *vector::borrow(power_up_value, 1) * upgrade.amount;
            };
            i = i+1;
        };
        // loop over game_store.upgrades - calculate dpm * current_upgrade.amount to get the total diamonds_per_minute
        dpm
        // return diamonds_per_minute of all the user's powerups
    }

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
        let game_store = borrow_global<GameStore>(account_address);
        return game_store.upgrades
    }

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}
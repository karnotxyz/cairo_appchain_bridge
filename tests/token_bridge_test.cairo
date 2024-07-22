#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use core::serde::Serde;
    use core::result::ResultTrait;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use snforge_std as snf;
    use snforge_std::{ContractClassTrait, EventSpy, EventSpyTrait, EventSpyAssertionsTrait};
    use starknet::{ContractAddress, storage::StorageMemberAccessTrait};
    use starknet_bridge::mocks::erc20::ERC20;
    use starknet_bridge::bridge::{
        ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait, ITokenBridgeAdminDispatcher,
        ITokenBridgeAdminDispatcherTrait, TokenBridge, TokenBridge::Event
    };

    use starknet::contract_address::{contract_address_const};


    fn deploy_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
        let recipient: felt252 = 'owner'.try_into().unwrap();

        let erc20Ch = snf::declare("ERC20").unwrap();
        let mut constructor_args = ArrayTrait::new();
        name.serialize(ref constructor_args);
        symbol.serialize(ref constructor_args);
        let fixed_supply: u256 = 1000000000;
        fixed_supply.serialize(ref constructor_args);
        recipient.serialize(ref constructor_args);

        let (usdc, _) = erc20Ch.deploy(@constructor_args).unwrap();
        return usdc;
    }


    fn deploy_token_bridge() -> (ContractAddress, EventSpy) {
        // Deploy messaging mock with 5 days cancellation delay
        let messaging_mock_class = snf::declare("messaging_mock").unwrap();
        let (messaging_contract_address, _) = messaging_mock_class.deploy(@array![432000]).unwrap();

        // Declare l3 bridge address
        let l3_bridge_address = contract_address_const::<'l3_bridge_address'>();

        // Declare owner
        let owner = contract_address_const::<'owner'>();

        let token_bridgeCH = snf::declare("TokenBridge").unwrap();

        let mut calldata = ArrayTrait::new();
        l3_bridge_address.serialize(ref calldata);
        messaging_contract_address.serialize(ref calldata);
        owner.serialize(ref calldata);

        let (token_bridge_address, _) = token_bridgeCH.deploy(@calldata).unwrap();

        let mut spy = snf::spy_events();

        (token_bridge_address, spy)
    }


    /// Returns the state of a component for testing. This must be used
    /// to test internal functions or directly access the storage.
    /// You can't spy event with this. Use deploy instead.
    fn mock_state_testing() -> TokenBridge::ContractState {
        TokenBridge::contract_state_for_testing()
    }

    #[test]
    fn constructor_ok() {
        deploy_token_bridge();
    }

    #[test]
    fn set_appchain_bridge_ok() {
        let (token_bridge_address, mut spy) = deploy_token_bridge();
        let token_bridge_admin = ITokenBridgeAdminDispatcher {
            contract_address: token_bridge_address
        };
        let token_bridge = ITokenBridgeDispatcher { contract_address: token_bridge_address };

        // Assert for old bridge address
        let old_appchain_bridge_address = token_bridge.appchain_bridge();
        assert(
            old_appchain_bridge_address == contract_address_const::<'l3_bridge_address'>(),
            'L3 Bridge address incorrect'
        );

        // Cheat for the owner
        snf::start_cheat_caller_address('owner'.try_into().unwrap(), token_bridge_address);

        // Set and check new bridge
        let new_appchain_bridge_address = contract_address_const::<'l3_bridge_address_new'>();
        token_bridge_admin.set_appchain_token_bridge(new_appchain_bridge_address);
        assert(
            token_bridge.appchain_bridge() == new_appchain_bridge_address, 'Appchain bridge not set'
        );
        snf::stop_cheat_caller_address(token_bridge_address);

        let expected_event = TokenBridge::SetAppchainBridge {
            appchain_bridge: new_appchain_bridge_address
        };
        spy
            .assert_emitted(
                @array![(token_bridge_address, Event::SetAppchainBridge(expected_event))]
            );
    }
}


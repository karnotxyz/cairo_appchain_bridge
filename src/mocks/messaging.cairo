use piltover::messaging::output_process::MessageToAppchain;
use starknet::ContractAddress;
#[starknet::interface]
pub trait IMockMessaging<TState> {
    fn update_state_for_message(ref self: TState, message_hash: felt252);
    fn process_last_message_to_appchain(
        ref self: TState, to_address: ContractAddress, selector: felt252, payload: Span<felt252>
    );
    fn process_message_to_starknet(
        ref self: TState, from: ContractAddress, to_address: ContractAddress, payload: Span<felt252>
    );
}

#[starknet::contract]
mod messaging_mock {
    use piltover::messaging::{
        output_process::MessageToAppchain, messaging_cpt,
        messaging_cpt::InternalTrait as MessagingInternal, IMessaging
    };
    use starknet::ContractAddress;
    use starknet_bridge::mocks::hash;
    use starknet_bridge::constants;
    use super::IMockMessaging;

    component!(path: messaging_cpt, storage: messaging, event: MessagingEvent);

    #[abi(embed_v0)]
    impl MessagingImpl = messaging_cpt::MessagingImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        messaging: messaging_cpt::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MessagingEvent: messaging_cpt::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, cancellation_delay_secs: u64) {
        self.messaging.initialize(cancellation_delay_secs);
    }


    #[abi(embed_v0)]
    impl MockMessagingImpl of IMockMessaging<ContractState> {
        fn update_state_for_message(ref self: ContractState, message_hash: felt252) {
            self.messaging.sn_to_appc_messages.write(message_hash, 0);
        }

        fn process_last_message_to_appchain(
            ref self: ContractState,
            to_address: ContractAddress,
            selector: felt252,
            payload: Span<felt252>
        ) {
            let nonce = self.messaging.sn_to_appc_nonce.read();
            let message_hash = hash::compute_message_hash_sn_to_appc(
                nonce, to_address, selector, payload
            );
            self.update_state_for_message(message_hash);
        }

        fn process_message_to_starknet(
            ref self: ContractState,
            from: ContractAddress,
            to_address: ContractAddress,
            payload: Span<felt252>
        ) {
            let message_hash = hash::compute_message_hash_appc_to_sn(from, to_address, payload);
            let ref_count = self.messaging.appc_to_sn_messages.read(message_hash);
            self.messaging.appc_to_sn_messages.write(message_hash, ref_count + 1);
        }
    }
}

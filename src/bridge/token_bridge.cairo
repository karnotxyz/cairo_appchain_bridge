#[starknet::contract]
pub mod TokenBridge {
    // use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    // use core::option::OptionTrait;
    // use core::traits::TryInto;
    // use core::starknet::event::EventEmitter;
    // use core::traits::PanicDestruct;
    use core::array::ArrayTrait;
    use core::serde::Serde;
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20MetadataDispatcher, IERC20DispatcherTrait,
        IERC20MetadataDispatcherTrait
    };

    use cairo_appchain_bridge::bridge::test::NewComponent as WithdrawalLimitComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    // use cairo_appchain_bridge::withdrawal_limit::component::WithdrawalLimitComponent;
    use cairo_appchain_bridge::withdrawal_limit::interface::IWithdrawalLimit;

    // component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: WithdrawalLimitComponent, storage: ownable, event: WithdrawalEvent);


    use core::num::traits::zero::Zero;
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_block_timestamp};

    use cairo_appchain_bridge::bridge::interface::{
        TokenStatus, TokenSettings, ITokenBridge, ITokenBridgeAdmin
    };
    use piltover::messaging::interface::IMessagingDispatcher;
    use piltover::messaging::interface::IMessagingDispatcherTrait;
    use cairo_appchain_bridge::constants;
    use starknet::ClassHash;


    // Ownable
    // #[abi(embed_v0)]
    // impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    // impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // WithdrawalLimit
    #[abi(embed_v0)]
    impl WithdrawalLimitImpl = WithdrawalLimitComponent::OwnableImpl<ContractState>;
    impl WithdrawalLimitInternal = WithdrawalLimitComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        appchain_bridge: ContractAddress,
        messaging_contract: IMessagingDispatcher,
        token_settings: LegacyMap<ContractAddress, TokenSettings>,
        // #[substorage(v0)]
        // ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: WithdrawalLimitComponent::Storage
    }

    // 
    // Errors 
    //
    pub mod Errors {
        pub const APPCHAIN_BRIDGE_NOT_SET: felt252 = 'L3 bridge not set';
        pub const ZERO_DEPOSIT: felt252 = 'Zero amount';
        pub const ALREADY_ENROLLED: felt252 = 'Already enrolled';
        pub const DEPLOYMENT_MESSAGE_NOT_EXIST: felt252 = 'Deployment message inexistent';
        pub const CANNOT_DEACTIVATE: felt252 = 'Cannot deactivate and block';
        pub const CANNOT_BLOCK: felt252 = 'Cannot block';
        pub const INVALID_RECIPIENT: felt252 = 'Invalid recipient';
    }


    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        TokenEnrollmentInitiated: TokenEnrollmentInitiated,
        TokenDeactivated: TokenDeactivated,
        TokenBlocked: TokenBlocked,
        Deposit: Deposit,
        DepositWithMessage: DepositWithMessage,
        DepostiCancelRequest: DepositCancelRequest,
        DepositWithMessageCancelRequest: DepositWithMessageCancelRequest,
        DepositReclaimed: DepositReclaimed,
        DepositWithMessageReclaimed: DepositWithMessageReclaimed,
        Withdrawal: Withdrawal,
        WithdrawalLimitEnabled: WithdrawalLimitEnabled,
        WithdrawalLimitDisabled: WithdrawalLimitDisabled,
        SetMaxTotalBalance: SetMaxTotalBalance,
        // #[flat]
        // OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        WithdrawalEvent: WithdrawalLimitComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct TokenDeactivated {
        token: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TokenBlocked {
        token: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TokenEnrollmentInitiated {
        token: ContractAddress,
        deployment_message_hash: felt252
    }


    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        nonce: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DepositWithMessage {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        message: Span<felt252>,
        nonce: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DepositCancelRequest {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        nonce: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DepositWithMessageCancelRequest {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        message: Span<felt252>,
        nonce: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct DepositReclaimed {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        nonce: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct DepositWithMessageReclaimed {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        #[key]
        appchain_recipient: ContractAddress,
        message: Span<felt252>,
        nonce: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawal {
        #[key]
        recipient: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalLimitEnabled {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalLimitDisabled {
        #[key]
        sender: ContractAddress,
        #[key]
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SetMaxTotalBalance {
        #[key]
        token: ContractAddress,
        value: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        appchain_bridge: ContractAddress,
        messaging_contract: ContractAddress,
        owner: ContractAddress
    ) {
        self.appchain_bridge.write(appchain_bridge);
        self
            .messaging_contract
            .write(IMessagingDispatcher { contract_address: messaging_contract });
        self.ownable.initializer(owner);
    }


    #[generate_trait]
    impl TokenBridgeInternalImpl of TokenBridgeInternal {
        fn deployment_message_payload(
            self: @ContractState, token: ContractAddress
        ) -> Span<felt252> {
            // Create the calldata that will be sent to on_receive. l2_token, amount and
            // depositor are the fields from the deposit context.
            let mut calldata = ArrayTrait::new();
            let dispatcher = IERC20MetadataDispatcher { contract_address: token };
            dispatcher.name().serialize(ref calldata);
            dispatcher.symbol().serialize(ref calldata);
            dispatcher.decimals().serialize(ref calldata);
            calldata.span()
        }


        fn accept_deposit(self: @ContractState, token: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let dispatcher = IERC20Dispatcher { contract_address: token };
            assert(dispatcher.balance_of(caller) == amount, 'Not enough balance');
            dispatcher.transfer_from(caller, get_contract_address(), amount);
        }

        fn send_deploy_message(self: @ContractState, token: ContractAddress) -> felt252 {
            assert(self.appchain_bridge().is_non_zero(), Errors::APPCHAIN_BRIDGE_NOT_SET);

            let (hash, _nonce) = self
                .messaging_contract
                .read()
                .send_message_to_appchain(
                    self.appchain_bridge(),
                    constants::HANDLE_TOKEN_DEPLOYMENT_SELECTOR,
                    self.deployment_message_payload(token)
                );
            return hash;
        }

        fn emit_deposit_event(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            message: Span<felt252>,
            selector: felt252,
            nonce: felt252,
        ) {
            let is_with_message = selector == constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR;
            let caller = get_caller_address();
            if (is_with_message) {
                self
                    .emit(
                        DepositWithMessage {
                            sender: caller,
                            token: token,
                            amount: amount,
                            appchain_recipient: appchain_recipient,
                            message: message,
                            nonce: nonce,
                        }
                    );
            } else {
                assert(selector == constants::HANDLE_TOKEN_DEPOSIT_SELECTOR, 'Unknown Selector');
                self
                    .emit(
                        Deposit {
                            sender: caller,
                            token: token,
                            amount: amount,
                            appchain_recipient: appchain_recipient,
                            nonce: nonce,
                        }
                    )
            }
        }

        fn send_deposit_message(
            self: @ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            message: Span<felt252>,
            selector: felt252,
        ) -> felt252 {
            assert(self.appchain_bridge().is_non_zero(), Errors::APPCHAIN_BRIDGE_NOT_SET);
            assert(amount > 0, Errors::ZERO_DEPOSIT);

            let is_with_message = selector == constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR;
            let (_, nonce) = self
                .messaging_contract
                .read()
                .send_message_to_appchain(
                    self.appchain_bridge(),
                    selector,
                    deposit_message_payload(
                        token, amount, appchain_recipient, is_with_message, message
                    )
                );
            return nonce;
        }

        fn consume_message(
            self: @ContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
        ) {
            let appchain_bridge = self.appchain_bridge();
            assert(appchain_bridge.is_non_zero(), Errors::APPCHAIN_BRIDGE_NOT_SET);
            let mut payload = ArrayTrait::new();
            constants::TRANSFER_FROM_STARKNET.serialize(ref payload);
            recipient.serialize(ref payload);
            amount.serialize(ref payload);
            self
                .messaging_contract
                .read()
                .consume_message_from_appchain(appchain_bridge, payload.span());
        }

        fn _block_token(ref self: ContractState, token: ContractAddress) {
            let new_settings = TokenSettings {
                token_status: TokenStatus::Blocked, ..self.token_settings.read(token)
            };
            self.token_settings.write(token, new_settings);
        }
    }


    fn deposit_message_payload(
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        is_with_message: bool,
        message: Span<felt252>
    ) -> Span<felt252> {
        let caller = get_caller_address();
        let mut payload = ArrayTrait::new();
        token.serialize(ref payload);
        caller.serialize(ref payload);
        appchain_recipient.serialize(ref payload);
        amount.serialize(ref payload);
        if (is_with_message) {
            message.serialize(ref payload);
        }

        return payload.span();
    }

    #[abi(embed_v0)]
    impl TokenBrdigeAdminImpl of ITokenBridgeAdmin<ContractState> {
        fn set_appchain_token_bridge(ref self: ContractState, appchain_bridge: ContractAddress) {
            self.appchain_bridge.write(appchain_bridge);
        }

        // Deactivates a token in the system.
        // This fun ction is used to deactivate a token that was previously enrolled.
        // Only the manager, who initiated the enrollment, can call this function.
        //
        // @param token The address of the token contract to be deactivated.
        // No return value, but it updates the token's status to 'Deactivated'.
        // Emits a `TokenDeactivated` event when the deactivation is successful.
        // Throws an error if the token is not enrolled or if the sender is not the manager.
        fn block_token(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            let settings = self.token_settings.read(token);
            assert(settings.token_status == TokenStatus::Unknown, Errors::CANNOT_BLOCK);

            self._block_token(:token);
            self.emit(TokenBlocked { token });
        }


        fn deactivate_and_block_token(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            let settings = self.token_settings.read(token);
            assert(
                settings.token_status == TokenStatus::Active
                    || settings.token_status == TokenStatus::Pending,
                Errors::CANNOT_DEACTIVATE
            );

            self._block_token(:token);

            self.emit(TokenDeactivated { token });
            self.emit(TokenBlocked { token });
        }

        fn enable_withdrawal_limit(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            let new_settings = TokenSettings {
                withdrawal_limit_applied: true, ..self.token_settings.read(token)
            };
            self.token_settings.write(token, new_settings);
            self.emit(WithdrawalLimitEnabled { sender: get_caller_address(), token });
        }

        fn disable_withdrawal_limit(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            let new_settings = TokenSettings {
                withdrawal_limit_applied: false, ..self.token_settings.read(token)
            };
            self.token_settings.write(token, new_settings);
            self.emit(WithdrawalLimitDisabled { sender: get_caller_address(), token });
        }

        fn set_max_total_balance(
            ref self: ContractState, token: ContractAddress, max_total_balance: u256
        ) {
            self.ownable.assert_only_owner();
            let new_settings = TokenSettings {
                max_total_balance: max_total_balance, ..self.token_settings.read(token)
            };
            self.token_settings.write(token, new_settings);
            self.emit(SetMaxTotalBalance { token, value: max_total_balance });
        }
    }

    #[abi(embed_v0)]
    impl TokenBridgeImpl of ITokenBridge<ContractState> {
        fn appchain_bridge(self: @ContractState) -> ContractAddress {
            return self.appchain_bridge.read();
        }

        fn identity(self: @ContractState) -> ByteArray {
            "cairo_appchain_bridge"
        }


        fn enroll_token(ref self: ContractState, token: ContractAddress) {
            let status = self.token_settings.read(token).token_status;
            assert(status == TokenStatus::Unknown, Errors::ALREADY_ENROLLED);

            // Send message to appchain
            let deployment_message_hash = self.send_deploy_message(token);

            // TODO: check the deployment msg has been sent by calling l1ToL2Messages() > 0

            // Dep(piltover): Will uncomment once piltover updates interface
            // let nonce = self
            //     .messaging_contract
            //     .read()
            //     .sn_to_appchain_messages(deployment_message_hash);
            // assert(nonce > 0, Errors::DEPLOYMENT_MESSAGE_NOT_EXIST);

            let token_status = TokenSettings {
                token_status: TokenStatus::Pending,
                deployment_message_hash: deployment_message_hash,
                pending_deployment_expiration: get_block_timestamp()
                    + constants::MAX_PENDING_DURATION.try_into().unwrap(),
                max_total_balance: core::integer::BoundedInt::max(),
                withdrawal_limit_applied: false
            };

            self.token_settings.write(token, token_status);
            self.emit(TokenEnrollmentInitiated { token, deployment_message_hash });
        }

        fn deposit(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress
        ) {
            let no_message: Span<felt252> = array![].span();
            self.accept_deposit(token, amount);
            let nonce = self
                .send_deposit_message(
                    token,
                    amount,
                    appchain_recipient,
                    no_message.clone(),
                    constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
                );
            self
                .emit_deposit_event(
                    token,
                    amount,
                    appchain_recipient,
                    no_message,
                    constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
                    nonce,
                );
            self.check_deployment_status(token);
        }


        fn deposit_with_message(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            message: Span<felt252>
        ) {
            self.accept_deposit(token, amount);
            let nonce = self
                .send_deposit_message(
                    token,
                    amount,
                    appchain_recipient,
                    message,
                    constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR,
                );

            self
                .emit_deposit_event(
                    token,
                    amount,
                    appchain_recipient,
                    message,
                    constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR,
                    nonce
                );

            // Piggy-back the deposit tx to check and update the status of token bridge deployment.
            self.check_deployment_status(token);
        }
        //
        //     checks token deployment status.
        //     relies on starknet clearing l1-l2 message upon successful completion of deployment.
        //     processing: check the l1-l2 deployment message. set status to `active` if consumed.
        //     if not consumed after the expected duration, it returns the status to unknown.
        //
        fn check_deployment_status(ref self: ContractState, token: ContractAddress) {
            let settings = self.token_settings.read(token);
            if (settings.token_status == TokenStatus::Pending) {
                return;
            }

            let _msg_hash = settings.deployment_message_hash;
        // DEP(piltover) : to uncomment once the interface of piltover changes
        // if (self.messaging_contract.read().sn_to_appchain_messages(msg_hash) > 0) {
        //     let new_settings = TokenSettings {
        //         token_status: TokenStatus::Active, ..settings
        //     };
        //     self.token_settings.write(token, new_settings);
        // } else if (get_block_timestamp() > settings.pending_deployment_expiration) {
        //     let new_settings = TokenSettings {
        //         token_status: TokenStatus::Unknown,
        //         deployment_msg_hash: 0,
        //         pending_deployment_expiration: 0,
        //         max_total_balance: 0,
        //         withdrawal_limit_applied: false
        //     };
        //     self.token_settings.write(token, new_settings);
        // }

        }


        fn withdraw(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            recipient: ContractAddress
        ) {
            assert(recipient.is_non_zero(), Errors::INVALID_RECIPIENT);

            self.consume_message(token, amount, recipient);
            let settings = self.token_settings.read(token);
            // TODO: Consume quota from here
            // DEP(byteZorvin): Complete the withdrawal component in cairo 
            if (settings.withdrawal_limit_applied) {}
            let tokenDispatcher = IERC20Dispatcher { contract_address: token };
            tokenDispatcher.transfer(recipient, amount);
            self.emit(Withdrawal { recipient, token, amount });
        }

        // /*
        //   A deposit cancellation requires two steps:
        //   1. The depositor should send a depositCancelRequest request with deposit details & nonce.
        //   2. After a predetermined time (cancellation delay), the depositor can claim back the funds by
        //      calling depositReclaim (using the same arguments).
        //
        //   Note: As long as the depositReclaim was not performed, the deposit may be processed, even if
        //         the cancellation delay time has already passed. Only the depositor is allowed to cancel
        //         a deposit, and only before depositReclaim was performed.
        // */
        fn deposit_cancel_request(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            nonce: felt252
        ) {
            let no_message: Span<felt252> = array![].span();
            self
                .messaging_contract
                .read()
                .start_message_cancellation(
                    self.appchain_bridge(),
                    constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
                    deposit_message_payload(token, amount, appchain_recipient, false, no_message),
                    nonce
                );
            self
                .emit(
                    DepositCancelRequest {
                        sender: get_caller_address(), token, amount, appchain_recipient, nonce
                    }
                );
        }

        fn deposit_with_message_cancel_request(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            message: Span<felt252>,
            nonce: felt252
        ) {
            self
                .messaging_contract
                .read()
                .start_message_cancellation(
                    self.appchain_bridge(),
                    constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR,
                    deposit_message_payload(token, amount, appchain_recipient, true, message),
                    nonce
                );
            self
                .emit(
                    DepositWithMessageCancelRequest {
                        sender: get_caller_address(),
                        token,
                        amount,
                        appchain_recipient,
                        message,
                        nonce
                    }
                );
        }

        fn deposit_with_message_reclaim(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            message: Span<felt252>,
            nonce: felt252
        ) {
            self
                .messaging_contract
                .read()
                .cancel_message(
                    self.appchain_bridge(),
                    constants::HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR,
                    deposit_message_payload(token, amount, appchain_recipient, true, message),
                    nonce
                );

            let dispatcher = IERC20Dispatcher { contract_address: token };
            dispatcher.transfer(get_caller_address(), amount);

            self
                .emit(
                    DepositWithMessageReclaimed {
                        sender: get_caller_address(),
                        token,
                        amount,
                        appchain_recipient,
                        message,
                        nonce
                    }
                );
        }

        fn deposit_reclaim(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            appchain_recipient: ContractAddress,
            nonce: felt252
        ) {
            let no_message: Span<felt252> = array![].span();
            self
                .messaging_contract
                .read()
                .cancel_message(
                    self.appchain_bridge(),
                    constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
                    deposit_message_payload(token, amount, appchain_recipient, false, no_message),
                    nonce
                );

            let dispatcher = IERC20Dispatcher { contract_address: token };
            dispatcher.transfer(get_caller_address(), amount);

            self
                .emit(
                    DepositReclaimed {
                        sender: get_caller_address(), token, amount, appchain_recipient, nonce
                    }
                );
        }


        fn getStatus(self: @ContractState, token: ContractAddress) -> TokenStatus {
            self.token_settings.read(token).token_status
        }

        fn isServicingToken(self: @ContractState, token: ContractAddress) -> bool {
            self.token_settings.read(token).token_status == TokenStatus::Active
        }

        // /**
        //     Returns the remaining amount of withdrawal allowed for this day.
        //     If the daily allowance was not yet set, it is calculated and returned.
        //     If the withdraw limit is not enabled for that token - the uint256.max is returned.
        //  */
        // function getRemainingIntradayAllowance(address token) external view returns (uint256) {
        //     return
        //         tokenSettings()[token].withdrawalLimitApplied
        //             ? WithdrawalLimit.getRemainingIntradayAllowance(token)
        //             : type(uint256).max;
        // }
        fn get_remaining_intraday_allowance(self: @ContractState, token: ContractAddress) -> u256 {
            if (self.token_settings.read(token).withdrawal_limit_applied) {
                return core::integer::BoundedInt::max();
            }
            // TODO: Write the WithdrawalLimit functionality
            return 0;
        }

        fn is_withdrawal_limit_applied(self: @ContractState, token: ContractAddress) -> bool {
            self.token_settings.read(token).withdrawal_limit_applied
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}


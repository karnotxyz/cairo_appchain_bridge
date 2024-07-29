use starknet::ContractAddress;
use starknet_bridge::bridge::types::{TokenStatus, TokenSettings};

#[starknet::interface]
pub trait ITokenBridgeAdmin<TContractState> {
    fn set_appchain_token_bridge(ref self: TContractState, appchain_bridge: ContractAddress);
    fn block_token(ref self: TContractState, token: ContractAddress);
    fn deactivate_and_block_token(ref self: TContractState, token: ContractAddress);
    fn enable_withdrawal_limit(ref self: TContractState, token: ContractAddress);
    fn disable_withdrawal_limit(ref self: TContractState, token: ContractAddress);
    fn set_max_total_balance(
        ref self: TContractState, token: ContractAddress, max_total_balance: u256
    );
}

#[starknet::interface]
pub trait ITokenBridge<TContractState> {
    fn appchain_bridge(self: @TContractState) -> ContractAddress;
    fn identity(self: @TContractState) -> ByteArray;
    fn get_status(self: @TContractState, token: ContractAddress) -> TokenStatus;
    fn is_servicing_token(self: @TContractState, token: ContractAddress) -> bool;
    fn is_withdrawal_limit_applied(self: @TContractState, token: ContractAddress) -> bool;

    fn enroll_token(ref self: TContractState, token: ContractAddress);
    fn check_deployment_status(ref self: TContractState, token: ContractAddress);

    fn deposit(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress
    );
    fn deposit_with_message(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        message: Span<felt252>
    );

    fn withdraw(
        ref self: TContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
    );

    fn deposit_cancel_request(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        nonce: felt252
    );
    fn deposit_with_message_cancel_request(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        message: Span<felt252>,
        nonce: felt252
    );

    fn deposit_with_message_reclaim(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        message: Span<felt252>,
        nonce: felt252
    );
    fn deposit_reclaim(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        appchain_recipient: ContractAddress,
        nonce: felt252
    );
    fn get_remaining_intraday_allowance(self: @TContractState, token: ContractAddress) -> u256;
    fn get_max_total_balance(self: @TContractState, token: ContractAddress) -> u256;
}

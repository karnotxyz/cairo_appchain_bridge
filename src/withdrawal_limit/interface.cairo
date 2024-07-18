use starknet::ContractAddress;

#[starknet::interface]
pub trait IWithdrawalLimit<TState> {// fn get_remaining_withdrawal_quota(self: @TState, token: ContractAddress) -> u256;
}

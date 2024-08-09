use starknet_bridge::bridge::token_bridge::TokenBridge::__member_module_token_settings::InternalContractMemberStateTrait;
use snforge_std as snf;
use starknet::{ContractAddress, storage::StorageMemberAccessTrait};
use starknet_bridge::mocks::{
    messaging::{IMockMessagingDispatcherTrait, IMockMessagingDispatcher}, erc20::ERC20
};
use starknet_bridge::bridge::{
    ITokenBridge, ITokenBridgeAdmin, ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait,
    ITokenBridgeAdminDispatcher, ITokenBridgeAdminDispatcherTrait, IWithdrawalLimitStatusDispatcher,
    IWithdrawalLimitStatusDispatcherTrait, TokenBridge, TokenBridge::Event,
    types::{TokenStatus, TokenSettings}
};
use openzeppelin::access::ownable::{
    OwnableComponent, OwnableComponent::Event as OwnableEvent,
    interface::{IOwnableTwoStepDispatcher, IOwnableTwoStepDispatcherTrait}
};
use starknet::contract_address::{contract_address_const};

use starknet_bridge::bridge::tests::constants::{
    OWNER, L3_BRIDGE_ADDRESS, USDC_MOCK_ADDRESS, DELAY_TIME
};


/// Returns the state of a contract for testing. This must be used
/// to test internal functions or directly access the storage.
/// You can't spy event with this. Use deploy instead.
pub fn mock_state_testing() -> TokenBridge::ContractState {
    TokenBridge::contract_state_for_testing()
}

#[test]
fn unblock_token_ok() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(usdc_address, TokenSettings { token_status: TokenStatus::Blocked, ..old_settings });

    mock.ownable.Ownable_owner.write(OWNER());
    snf::start_cheat_caller_address_global(OWNER());

    mock.unblock_token(usdc_address);
    assert(mock.get_status(usdc_address) == TokenStatus::Unknown, 'Not unblocked');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn unblock_token_not_owner() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(usdc_address, TokenSettings { token_status: TokenStatus::Blocked, ..old_settings });

    mock.ownable.Ownable_owner.write(OWNER());
    snf::start_cheat_caller_address_global(snf::test_address());

    mock.unblock_token(usdc_address);
}


#[test]
#[should_panic(expected: ('Token not blocked',))]
fn unblock_token_not_blocked() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(usdc_address, TokenSettings { token_status: TokenStatus::Active, ..old_settings });

    mock.ownable.Ownable_owner.write(OWNER());
    snf::start_cheat_caller_address_global(OWNER());

    mock.unblock_token(usdc_address);
}

#[test]
fn reactivate_token_ok() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(
            usdc_address, TokenSettings { token_status: TokenStatus::Deactivated, ..old_settings }
        );

    mock.ownable.Ownable_owner.write(OWNER());

    snf::start_cheat_caller_address_global(OWNER());

    mock.reactivate_token(usdc_address);
    assert(mock.get_status(usdc_address) == TokenStatus::Active, 'Did not reactivate');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn reactivate_token_not_owner() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(
            usdc_address, TokenSettings { token_status: TokenStatus::Deactivated, ..old_settings }
        );

    snf::start_cheat_caller_address_global(snf::test_address());

    mock.reactivate_token(usdc_address);
}

#[test]
#[should_panic(expected: ('Token not deactivated',))]
fn reactivate_token_not_deactivated() {
    let mut mock = mock_state_testing();
    let usdc_address = USDC_MOCK_ADDRESS();

    // Setting the token active
    let old_settings = mock.token_settings.read(usdc_address);
    mock
        .token_settings
        .write(usdc_address, TokenSettings { token_status: TokenStatus::Blocked, ..old_settings });

    mock.ownable.Ownable_owner.write(OWNER());
    snf::start_cheat_caller_address_global(OWNER());

    mock.reactivate_token(usdc_address);
}


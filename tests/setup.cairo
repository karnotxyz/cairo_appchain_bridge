use snforge_std as snf;
use snforge_std::{
    ContractClassTrait, EventSpy, EventSpyTrait, EventsFilterTrait, EventSpyAssertionsTrait
};
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
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::contract_address::{contract_address_const};
use super::constants::{OWNER, L3_BRIDGE_ADDRESS, DELAY_TIME};
use starknet_bridge::constants;
use starknet_bridge::bridge::tests::utils::message_payloads;


pub fn deploy_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let erc20_class_hash = snf::declare("ERC20").unwrap();
    let mut constructor_args = ArrayTrait::new();
    name.serialize(ref constructor_args);
    symbol.serialize(ref constructor_args);
    let fixed_supply: u256 = 1000000000;
    fixed_supply.serialize(ref constructor_args);
    OWNER().serialize(ref constructor_args);

    let (usdc, _) = erc20_class_hash.deploy(@constructor_args).unwrap();

    let usdc_token = IERC20Dispatcher { contract_address: usdc };

    // Transfering usdc to test address for testing
    snf::start_cheat_caller_address(usdc, OWNER());
    usdc_token.transfer(snf::test_address(), 100);
    snf::stop_cheat_caller_address(usdc);

    return usdc;
}

pub fn deploy_token_bridge_with_messaging() -> (
    ITokenBridgeDispatcher, EventSpy, IMockMessagingDispatcher
) {
    // Deploy messaging mock with 5 days cancellation delay
    let messaging_mock_class_hash = snf::declare("messaging_mock").unwrap();
    // Deploying with 5 days as the delay time (5 * 86400 = 432000)
    let (messaging_contract_address, _) = messaging_mock_class_hash
        .deploy(@array![DELAY_TIME])
        .unwrap();

    // Declare l3 bridge address
    let appchain_bridge_address = L3_BRIDGE_ADDRESS();

    // Declare owner
    let owner = OWNER();

    let token_bridge_class_hash = snf::declare("TokenBridge").unwrap();

    // Deploy the bridge
    let mut calldata = ArrayTrait::new();
    appchain_bridge_address.serialize(ref calldata);
    messaging_contract_address.serialize(ref calldata);
    owner.serialize(ref calldata);

    let (token_bridge_address, _) = token_bridge_class_hash.deploy(@calldata).unwrap();

    let token_bridge = ITokenBridgeDispatcher { contract_address: token_bridge_address };
    let messaging_mock = IMockMessagingDispatcher { contract_address: messaging_contract_address };

    let mut spy = snf::spy_events();
    (token_bridge, spy, messaging_mock)
}


pub fn deploy_token_bridge() -> (ITokenBridgeDispatcher, EventSpy) {
    let (token_bridge, spy, _) = deploy_token_bridge_with_messaging();
    (token_bridge, spy)
}


/// Returns the state of a contract for testing. This must be used
/// to test internal functions or directly access the storage.
/// You can't spy event with this. Use deploy instead.
pub fn mock_state_testing() -> TokenBridge::ContractState {
    TokenBridge::contract_state_for_testing()
}

pub fn enroll_token_and_settle(
    token_bridge: ITokenBridgeDispatcher,
    messaging_mock: IMockMessagingDispatcher,
    token: ContractAddress
) {
    assert(token_bridge.get_status(token) == TokenStatus::Unknown, 'Should be Unknown');

    token_bridge.enroll_token(token);
    assert(token_bridge.get_status(token) == TokenStatus::Pending, 'Should be Pending');

    // Settles the message sent to appchain
    messaging_mock
        .process_last_message_to_appchain(
            L3_BRIDGE_ADDRESS(),
            constants::HANDLE_TOKEN_DEPLOYMENT_SELECTOR,
            message_payloads::deployment_message_payload(token)
        );

    token_bridge.check_deployment_status(token);

    let final_status = token_bridge.get_status(token);
    assert(final_status == TokenStatus::Active, 'Should be Active');
}

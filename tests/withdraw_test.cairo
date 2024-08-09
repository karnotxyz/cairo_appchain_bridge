use core::num::traits::zero::Zero;
use starknet_bridge::bridge::token_bridge::TokenBridge::__member_module_token_settings::InternalContractMemberStateTrait;
use core::array::ArrayTrait;
use core::serde::Serde;
use core::result::ResultTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use snforge_std as snf;
use snforge_std::{
    ContractClassTrait, EventSpy, EventSpyTrait, EventsFilterTrait, EventSpyAssertionsTrait
};
use starknet::{ContractAddress, storage::StorageMemberAccessTrait};
use starknet_bridge::mocks::{
    messaging::{IMockMessagingDispatcherTrait, IMockMessagingDispatcher}, erc20::ERC20
};
use piltover::messaging::{IMessaging, IMessagingDispatcher, IMessagingDispatcherTrait};
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
use super::setup::{
    deploy_erc20, deploy_token_bridge_with_messaging, deploy_token_bridge, enroll_token_and_settle
};
use starknet_bridge::constants;
use starknet_bridge::bridge::tests::utils::message_payloads;

#[test]
fn withdraw_ok() {
    let (token_bridge, _, messaging_mock) = deploy_token_bridge_with_messaging();
    let usdc_address = deploy_erc20("usdc", "usdc");
    let usdc = IERC20Dispatcher { contract_address: usdc_address };

    snf::start_cheat_caller_address(usdc_address, OWNER());
    usdc.transfer(snf::test_address(), 100);
    snf::stop_cheat_caller_address(usdc_address);

    enroll_token_and_settle(token_bridge, messaging_mock, usdc_address);

    let amount = 100;
    usdc.approve(token_bridge.contract_address, amount);
    token_bridge.deposit(usdc_address, amount, snf::test_address());
    messaging_mock
        .process_last_message_to_appchain(
            L3_BRIDGE_ADDRESS(),
            constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
            message_payloads::deposit_message_payload(
                usdc_address,
                amount,
                snf::test_address(),
                snf::test_address(),
                false,
                array![].span()
            )
        );

    // Register a withdraw message from appchain to piltover
    messaging_mock
        .process_message_to_starknet(
            L3_BRIDGE_ADDRESS(),
            token_bridge.contract_address,
            message_payloads::withdraw_message_payload_from_appchain(
                usdc_address, amount, snf::test_address()
            )
        );

    let initial_bridge_balance = usdc.balance_of(token_bridge.contract_address);
    let initial_recipient_balance = usdc.balance_of(snf::test_address());
    token_bridge.withdraw(usdc_address, 100, snf::test_address());

    assert(
        usdc.balance_of(snf::test_address()) == initial_recipient_balance + amount,
        'Incorrect amount recieved'
    );

    assert(
        usdc.balance_of(token_bridge.contract_address) == initial_bridge_balance - amount,
        'Incorrect token amount'
    );
}

#[test]
#[should_panic(expected: ('INVALID_MESSAGE_TO_CONSUME',))]
fn withdraw_incorrect_recipient() {
    let (token_bridge, _, messaging_mock) = deploy_token_bridge_with_messaging();
    let usdc_address = deploy_erc20("usdc", "usdc");
    let usdc = IERC20Dispatcher { contract_address: usdc_address };

    snf::start_cheat_caller_address(usdc_address, OWNER());
    usdc.transfer(snf::test_address(), 100);
    snf::stop_cheat_caller_address(usdc_address);

    enroll_token_and_settle(token_bridge, messaging_mock, usdc_address);

    let amount = 100;
    usdc.approve(token_bridge.contract_address, amount);
    token_bridge.deposit(usdc_address, amount, snf::test_address());
    messaging_mock
        .process_last_message_to_appchain(
            L3_BRIDGE_ADDRESS(),
            constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
            message_payloads::deposit_message_payload(
                usdc_address,
                amount,
                snf::test_address(),
                snf::test_address(),
                false,
                array![].span()
            )
        );

    // Register a withdraw message from appchain to piltover
    messaging_mock
        .process_message_to_starknet(
            L3_BRIDGE_ADDRESS(),
            token_bridge.contract_address,
            message_payloads::withdraw_message_payload_from_appchain(
                usdc_address, amount, snf::test_address()
            )
        );

    token_bridge.withdraw(usdc_address, 100, contract_address_const::<'user2'>());
}


#[test]
#[should_panic(expected: ('LIMIT_EXCEEDED',))]
fn withdraw_limit_reached() {
    let (token_bridge, _, messaging_mock) = deploy_token_bridge_with_messaging();
    let usdc_address = deploy_erc20("usdc", "usdc");
    let usdc = IERC20Dispatcher { contract_address: usdc_address };
    let token_bridge_admin = ITokenBridgeAdminDispatcher {
        contract_address: token_bridge.contract_address
    };

    snf::start_cheat_caller_address(usdc_address, OWNER());
    usdc.transfer(snf::test_address(), 100);
    snf::stop_cheat_caller_address(usdc_address);

    enroll_token_and_settle(token_bridge, messaging_mock, usdc_address);

    let amount = 100;
    usdc.approve(token_bridge.contract_address, amount);
    token_bridge.deposit(usdc_address, amount, snf::test_address());
    messaging_mock
        .process_last_message_to_appchain(
            L3_BRIDGE_ADDRESS(),
            constants::HANDLE_TOKEN_DEPOSIT_SELECTOR,
            message_payloads::deposit_message_payload(
                usdc_address,
                amount,
                snf::test_address(),
                snf::test_address(),
                false,
                array![].span()
            )
        );

    snf::start_cheat_caller_address(token_bridge.contract_address, OWNER());
    token_bridge_admin.enable_withdrawal_limit(usdc_address);
    snf::stop_cheat_caller_address(token_bridge.contract_address);

    let withdraw_amount = 50;

    // Register a withdraw message from appchain to piltover
    messaging_mock
        .process_message_to_starknet(
            L3_BRIDGE_ADDRESS(),
            token_bridge.contract_address,
            message_payloads::withdraw_message_payload_from_appchain(
                usdc_address, withdraw_amount, snf::test_address()
            )
        );

    token_bridge.withdraw(usdc_address, withdraw_amount, snf::test_address());
}

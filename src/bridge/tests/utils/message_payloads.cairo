use starknet::ContractAddress;
use starknet_bridge::constants;

use openzeppelin::token::erc20::interface::{
    IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait
};

pub fn deposit_message_payload(
    token: ContractAddress,
    amount: u256,
    caller: ContractAddress,
    appchain_recipient: ContractAddress,
    is_with_message: bool,
    message: Span<felt252>
) -> Span<felt252> {
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

pub fn deployment_message_payload(token: ContractAddress) -> Span<felt252> {
    // Create the calldata that will be sent to on_receive. l2_token, amount and
    // depositor are the fields from the deposit context.
    let mut calldata = ArrayTrait::new();
    let dispatcher = IERC20MetadataDispatcher { contract_address: token };
    token.serialize(ref calldata);
    dispatcher.name().serialize(ref calldata);
    dispatcher.symbol().serialize(ref calldata);
    dispatcher.decimals().serialize(ref calldata);
    calldata.span()
}

pub fn withdraw_message_payload_from_appchain(
    token: ContractAddress, amount: u256, recipient: ContractAddress
) -> Span<felt252> {
    let mut message_payload = ArrayTrait::new();
    constants::TRANSFER_FROM_APPCHAIN.serialize(ref message_payload);
    recipient.serialize(ref message_payload);
    token.serialize(ref message_payload);
    amount.serialize(ref message_payload);
    message_payload.span()
}

// These constants have been take from this [Starkgate Bridge contract constants](https://github.com/starknet-io/starkgate-contracts/blob/cairo-1/src/solidity/StarkgateConstants.sol#L4)

// Starknet L1 handler selectors.
pub const HANDLE_TOKEN_DEPOSIT_SELECTOR: felt252 =
    774397379524139446221206168840917193112228400237242521560346153613428128537;

pub const HANDLE_DEPOSIT_WITH_MESSAGE_SELECTOR: felt252 =
    247015267890530308727663503380700973440961674638638362173641612402089762826;

pub const HANDLE_TOKEN_DEPLOYMENT_SELECTOR: felt252 =
    1737780302748468118210503507461757847859991634169290761669750067796330642876;
pub const MAX_PENDING_DURATION: felt252 = 5 * 86400;

// Renaming from TRANSFER_FROM_STARKNET to TRANSFER_FROM_APPCHAIN.
pub const TRANSFER_FROM_APPCHAIN: felt252 = 0;

// Withdrawal limit
pub const SECONDS_IN_DAY: u64 = 86400;

// When storing the remaining quota for today, we add 1 to the value. This is because we want
// that 0 will mean that it was not set yet.
pub const REMAINING_QUOTA_OFFSET: u256 = 1;

// starknet_keccak('on_receive').
pub const ON_RECEIVE_SELECTOR: felt252 =
    480768629706071032051132431608482761444818804172389941599997570483678682398;

pub const CONTRACT_IDENTITY: felt252 = 'STARKNET_BRIDGE';
pub const CONTRACT_VERSION: felt252 = '0.1.0';


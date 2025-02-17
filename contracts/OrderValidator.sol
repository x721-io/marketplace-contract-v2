// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/EIP712Upgradeable.sol";
import "../contracts/ContextUpgradeable.sol";
import "../contracts/library/LibSignature.sol";
import "../contracts/library/LibOrder.sol";

abstract contract OrderValidator is
    Initializable,
    ContextUpgradeable,
    EIP712Upgradeable
{
    using LibSignature for bytes32;
    using AddressUpgradeable for address;

    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    function __OrderValidator_init_unchained() internal initializer {
        __EIP712_init_unchained("X721Exchange", "1");
    }

    function validate(
        LibOrder.Order memory order,
        bytes memory signature
    ) internal view {
        require(order.maker != address(0), "no maker");
        if (order.salt == 0) {
            require(
                order.maker != address(0) && _msgSender() == order.maker,
                "maker is not tx sender"
            );
        } else {
            bytes32 hash;
            if (
                order.orderType == LibOrder.OrderType.SINGLE ||
                order.orderType == LibOrder.OrderType.BID
            ) {
                hash = LibOrder.hash(order);
            } else if (order.orderType == LibOrder.OrderType.BULK) {
                hash = LibOrder.hashBulkOrder(order, order.root);
            } else {
                revert("Unsupported order type");
            }

            if (_msgSender() != order.maker) {
                require(
                    _hashTypedDataV4(hash).recover(signature) == order.maker,
                    "order signature verification error"
                );
            }
        }
    }

    function validateCollectionBidOrder(
        LibOrder.BidCollectionOrder memory order,
        bytes memory signature
    ) internal view {
        if (order.salt == 0) {
            require(
                order.maker != address(0) && _msgSender() == order.maker,
                "maker is not tx sender"
            );
        } else {
            bytes32 hash = LibOrder.hashCollection(order);
            if (_msgSender() != order.maker) {
                require(
                    _hashTypedDataV4(hash).recover(signature) == order.maker,
                    "order signature verification for bid collection order error"
                );
                require(order.maker != address(0), "no maker");
            }
        }
    }

    uint256[50] private __gap;
}

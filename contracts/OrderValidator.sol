// SPDX-License-Identifier: MIT;
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
        if (order.salt == 0) {
            if (order.maker != address(0)) {
                require(_msgSender() == order.maker, "maker is not tx sender");
            }
        } else {
            if (
                order.orderType == LibOrder.OrderType.SINGLE ||
                order.orderType == LibOrder.OrderType.BID
            ) {
                bytes32 hash = LibOrder.hash(order);
                if (_msgSender() != order.maker) {
                    // if maker is contract checking ERC1271 signature
                    // if (order.maker.isContract()) {
                    //     require(
                    //         IERC1271(order.maker).isValidSignature(
                    //             _hashTypedDataV4(hash),
                    //             signature
                    //         ) == MAGICVALUE,
                    //         "contract order signature verification error"
                    //     );
                    if (
                        _hashTypedDataV4(hash).recover(signature) != order.maker
                    ) {
                        revert("order signature verification error");
                    } else {
                        require(order.maker != address(0), "no maker");
                    }
                }
            } else if (order.orderType == LibOrder.OrderType.BID_COLLECTION) {
                bytes32 hash = LibOrder.hashCollection(order);
                if (_msgSender() != order.maker) {
                    // if maker is contract checking ERC1271 signature
                    // if (order.maker.isContract()) {
                    //     require(
                    //         IERC1271(order.maker).isValidSignature(
                    //             _hashTypedDataV4(hash),
                    //             signature
                    //         ) == MAGICVALUE,
                    //         "contract order signature verification error"
                    //     );
                    if (
                        _hashTypedDataV4(hash).recover(signature) != order.maker
                    ) {
                        revert("order signature verification error");
                    } else {
                        require(order.maker != address(0), "no maker");
                    }
                }
            } else {
                if (_msgSender() != order.maker) {
                    bytes32 hash = LibOrder.hashBulkOrder(order, order.root);
                    if (
                        _hashTypedDataV4(hash).recover(signature) != order.maker
                    ) {
                        revert("order signature verification error");
                    } else {
                        require(order.maker != address(0), "no maker");
                    }
                }
            }
        }
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../../contracts/SafeMathUpgradeable.sol";
import "../../contracts/library/LibAsset.sol";
import "../../contracts/library/LibMath.sol";

library LibOrder {
    using SafeMathUpgradeable for uint256;

    bytes32 constant ORDER_TYPEHASH =
        keccak256(
            "Order(address maker,Asset makeAsset,address taker,Asset takeAsset,uint256 salt,uint256 start,uint256 end,uint16 index)Asset(uint8 assetType,address contractAddress,uint256 value,uint256 id)"
        );

    bytes32 constant COLLECTION_ORDER_TYPEHASH =
        keccak256(
            "BidCollectionOrder(address maker,Asset makeAsset,address taker,CollectionAsset bidCollectionAsset,uint256 salt,uint256 start,uint256 end,uint16 index)Asset(uint8 assetType,address contractAddress,uint256 value,uint256 id)CollectionAsset(uint8 assetType,address contractAddress,uint256 value)"
        );

    bytes32 constant BULK_ORDER_TYPEHASH =
        keccak256("BulkOrder(address maker,bytes32 root,uint256 salt)");

    bytes4 constant DEFAULT_ORDER_TYPE = 0xffffffff;

    enum OrderType {
        SINGLE,
        BULK,
        BID,
        BID_COLLECTION
    }

    struct Fee {
        address receiver;
        uint256 amount;
    }

    struct Order {
        OrderType orderType;
        address maker;
        LibAsset.Asset makeAsset;
        address taker;
        LibAsset.Asset takeAsset;
        uint256 salt;
        uint256 start;
        uint256 end;
        Fee originFee;
        Fee royaltyFee;
        bytes sig;
        bytes32 root;
        bytes32[] proof;
        uint16 index;
    }

    struct BidCollectionOrder {
        address maker;
        LibAsset.Asset makeAsset;
        address taker;
        LibAsset.CollectionAsset bidCollectionAsset;
        uint256 salt;
        uint256 start;
        uint256 end;
        Fee originFee;
        Fee royaltyFee;
        bytes sig;
        bytes32 root;
        bytes32[] proof;
        uint16 index;
    }

    /**
     * @dev Calculate remaining make and take values of the order (after partial filling real make and take decrease)
     * @param order initial order to calculate remaining values for
     * @param fill current fill of the left order (0 if order is unfilled)
     * @param isMakeFill true if order fill is calculated from the make side, false if from the take side
     * @return makeValue remaining make value of the order. if fill = 0 then it's order's make value
     * @return takeValue remaining take value of the order. if fill = 0 then it's order's take value
     */
    function calculateRemaining(
        Order memory order,
        uint256 fill,
        bool isMakeFill
    ) internal pure returns (uint256 makeValue, uint256 takeValue) {
        if (isMakeFill) {
            makeValue = order.makeAsset.value.sub(fill);
            takeValue = LibMath.safeGetPartialAmountFloor(
                order.takeAsset.value,
                order.makeAsset.value,
                makeValue
            );
        } else {
            takeValue = order.takeAsset.value.sub(fill);
            makeValue = LibMath.safeGetPartialAmountFloor(
                order.makeAsset.value,
                order.takeAsset.value,
                takeValue
            );
        }
    }

    function hashKey(Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    order.maker,
                    LibAsset.hash(order.makeAsset),
                    LibAsset.hash(order.takeAsset),
                    order.salt
                )
            );
    }

    function hash(Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.maker,
                    LibAsset.hashAssetV2(order.makeAsset),
                    order.taker,
                    LibAsset.hashAssetV2(order.takeAsset),
                    order.salt,
                    order.start,
                    order.end,
                    order.index
                )
            );
    }

    function hashCollection(
        BidCollectionOrder memory order
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    COLLECTION_ORDER_TYPEHASH,
                    order.maker,
                    LibAsset.hashAssetV2(order.makeAsset),
                    order.taker,
                    LibAsset.hashCollectionAssetV2(order.bidCollectionAsset),
                    order.salt,
                    order.start,
                    order.end,
                    order.index
                )
            );
    }

    function hashBulkOrder(
        Order memory order,
        bytes32 root
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(BULK_ORDER_TYPEHASH, order.maker, root, order.salt)
            );
    }

    function hashMerkleLeaf(
        Order memory order
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    order.index,
                    order.maker,
                    order.makeAsset.contractAddress,
                    order.makeAsset.id,
                    order.makeAsset.value,
                    order.makeAsset.assetType,
                    order.taker,
                    order.takeAsset.contractAddress,
                    order.takeAsset.id,
                    order.takeAsset.value,
                    order.takeAsset.assetType
                )
            );
    }

    function validateOrderTime(Order memory order) internal view {
        require(
            order.start == 0 || order.start < block.timestamp,
            "Order start validation failed"
        );
        require(
            order.end == 0 || order.end > block.timestamp,
            "Order end validation failed"
        );
    }
}

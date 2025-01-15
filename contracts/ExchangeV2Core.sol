// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/OwnableUpgradeable.sol";
import "../contracts/AssetMatcher.sol";
import "../contracts/TransferExecutor.sol";
import "../contracts/OrderValidator.sol";
import "../contracts/library/LibDirectTransfer.sol";
import "../contracts/library/LibFill.sol";
import "../contracts/interface/ITransferManager.sol";

abstract contract ExchangeV2Core is
    Initializable,
    OwnableUpgradeable,
    AssetMatcher,
    TransferExecutor,
    OrderValidator,
    ITransferManager
{
    using SafeMathUpgradeable for uint256;
    using LibTransfer for address;

    uint256 private constant UINT256_MAX = type(uint256).max;
    uint randNonce = 0;

    mapping(bytes32 => uint256) public fills;
    mapping(address => mapping(bytes => mapping(uint16 => uint256)))
        private cancelledOrFiledOrders;

    event Cancel(bytes32 hash);
    event CancelOrder(address maker, bytes sig, uint16 index);
    event FillOrder(
        LibOrder.OrderType orderType,
        address maker,
        address taker,
        bytes sig,
        uint16 index,
        uint256 takeQty,
        uint256 takeAssetId,
        uint256 currentFilledValue,
        uint256 randomValue
    );
    event Match(
        bytes32 leftHash,
        bytes32 rightHash,
        uint256 newLeftFill,
        uint256 newRightFill
    );

    function randMod() internal returns (uint256) {
        randNonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            );
    }

    function cancel(LibOrder.Order memory order) external {
        require(_msgSender() == order.maker, "not a maker");
        require(order.salt != 0, "0 salt can't be used");
        bytes32 orderKeyHash = LibOrder.hashKey(order);
        fills[orderKeyHash] = UINT256_MAX;
        emit Cancel(orderKeyHash);
    }

    function cancelOrder(LibOrder.Order memory order) external {
        require(_msgSender() == order.maker, "not a maker");
        cancelledOrFiledOrders[_msgSender()][order.sig][order.index] = order
            .makeAsset
            .value;
        emit CancelOrder(_msgSender(), order.sig, order.index);
    }

    function directAcceptBid(
        LibDirectTransfer.AcceptBid calldata direct
    ) external payable {
        LibOrder.Order memory bidOrder = direct.bidOrder;
        LibOrder.Order memory sellOrder = direct.sellOrder;

        uint256 maxBidTakeAssetQty = bidOrder.takeAsset.value;
        uint256 acceptBidMakeAssetQty = sellOrder.makeAsset.value;

        require(
            acceptBidMakeAssetQty <= maxBidTakeAssetQty,
            "Accept bid qty higher than bid qty"
        );

        validateFull(bidOrder, bidOrder.sig);
        validateFull(sellOrder, sellOrder.sig);

        uint256 bidPricePerUnit = bidOrder.makeAsset.value / maxBidTakeAssetQty;
        uint256 totalBidPrice = bidPricePerUnit * acceptBidMakeAssetQty;

        require(
            totalBidPrice <= bidOrder.makeAsset.value,
            "Bid ERC-20 amount not enough"
        );

        bidOrder.makeAsset.value = totalBidPrice;
        bidOrder.takeAsset.value = acceptBidMakeAssetQty;
        bidOrder.taker = sellOrder.maker;

        sellOrder.makeAsset.value = maxBidTakeAssetQty;
        sellOrder.takeAsset.value = totalBidPrice;

        uint256 currentFilledAmt = cancelledOrFiledOrders[bidOrder.maker][
            bidOrder.sig
        ][bidOrder.index];

        validateTakeAssetAmount(sellOrder, bidOrder);
        matchAndTransfer(sellOrder, bidOrder, currentFilledAmt);
    }

    function matchOrders(
        LibOrder.Order[] memory orderLefts,
        LibOrder.Order[] memory orderRights
    ) external payable {
        require(
            orderLefts.length == orderRights.length,
            "lefts and rights length dont match"
        );

        for (uint256 i = 0; i < orderLefts.length; i++) {
            LibOrder.Order memory orderLeft = orderLefts[i];
            LibOrder.Order memory orderRight = orderRights[i];
            uint256 currentFilledAmt = cancelledOrFiledOrders[orderLeft.maker][
                orderLeft.sig
            ][orderLeft.index];

            validateBulkOrder(orderLeft);
            validateBulkOrder(orderRight);

            validateTakeAssetAmount(orderLeft, orderRight);
            validateOrders(orderLeft, orderRight);
            matchAndTransfer(orderLeft, orderRight, currentFilledAmt);
        }
    }

    function validateBulkOrder(LibOrder.Order memory order) internal view {
        if (order.orderType == LibOrder.OrderType.BULK) {
            bool isValidListing = validateListing(
                order.root,
                order.proof,
                order
            );
            require(isValidListing, "Invalid listing");
        }
    }

    function validateOrders(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal view {
        validateFull(orderLeft, orderLeft.sig);
        validateFull(orderRight, orderRight.sig);

        if (orderLeft.taker != address(0) && orderRight.maker != address(0)) {
            require(
                orderRight.maker == orderLeft.taker,
                "leftOrder.taker verification failed"
            );
        }
        if (orderRight.taker != address(0) && orderLeft.maker != address(0)) {
            require(
                orderRight.taker == orderLeft.maker,
                "rightOrder.taker verification failed"
            );
        }

        validateAssetMatching(orderLeft, orderRight);
    }

    function validateAssetMatching(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal view {
        validateAssetAmount(
            orderLeft,
            orderRight,
            orderRight.takeAsset.value,
            orderLeft.takeAsset.value
        );
        validateAssetAmount(
            orderRight,
            orderLeft,
            orderLeft.takeAsset.value,
            orderRight.takeAsset.value
        );
    }

    function validateAssetAmount(
        LibOrder.Order memory order,
        LibOrder.Order memory counterpartOrder,
        uint256 takeQty,
        uint256 pricePerUnit
    ) internal view {
        uint256 makeValue = order.makeAsset.assetType == 2
            ? order.makeAsset.value
            : msg.value;
        if (order.makeAsset.assetType == 2) {
            uint256 erc20Balance = IERC20Upgradeable(
                order.makeAsset.contractAddress
            ).balanceOf(order.maker);
            require(
                erc20Balance >= takeQty * pricePerUnit,
                "ERC20 balance not enough"
            );
        }
        require(
            takeQty * pricePerUnit <= makeValue,
            "Spending amount not enough"
        );
    }

    function matchAndTransfer(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        uint256 currentFilledAmt
    ) internal {
        (
            LibAsset.Asset memory makeMatch,
            LibAsset.Asset memory takeMatch
        ) = matchAssets(orderLeft, orderRight, currentFilledAmt);

        transferAssets(orderLeft, orderRight, makeMatch, takeMatch);

        LibOrder.Order memory makeOrder = orderLeft.orderType ==
            LibOrder.OrderType.BID
            ? orderRight
            : orderLeft;
        uint256 newFilledValue = cancelledOrFiledOrders[makeOrder.maker][
            makeOrder.sig
        ][makeOrder.index] + orderRight.takeAsset.value;
        cancelledOrFiledOrders[makeOrder.maker][makeOrder.sig][
            makeOrder.index
        ] = newFilledValue;

        emit FillOrder(
            orderLeft.orderType,
            orderLeft.maker,
            orderRight.maker,
            makeOrder.sig,
            makeOrder.index,
            orderRight.takeAsset.value,
            orderRight.takeAsset.id,
            newFilledValue,
            randMod()
        );
    }

    function transferAssets(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        LibAsset.Asset memory makeMatch,
        LibAsset.Asset memory takeMatch
    ) internal {
        doTransfers(
            createDealSide(orderLeft.maker, orderRight.maker, makeMatch),
            createDealSide(orderRight.maker, orderLeft.maker, takeMatch)
        );

        if (takeMatch.assetType == 1 || takeMatch.assetType == 2) {
            uint256 feeAmt = calculateFee(
                takeMatch.value,
                orderLeft.originFee.amount
            );
            uint256 royaltyFeeAmt = calculateFee(
                takeMatch.value,
                orderLeft.royaltyFee.amount
            );
            uint256 receivedAmt = takeMatch.value - feeAmt - royaltyFeeAmt;

            transferAssetWithFees(
                takeMatch,
                receivedAmt,
                feeAmt,
                royaltyFeeAmt,
                orderLeft,
                orderRight
            );
        } else {
            uint256 feeAmt = calculateFee(
                makeMatch.value,
                orderRight.originFee.amount
            );
            uint256 royaltyFeeAmt = calculateFee(
                makeMatch.value,
                orderRight.royaltyFee.amount
            );
            uint256 receivedAmt = makeMatch.value - feeAmt - royaltyFeeAmt;

            transferAssetWithFees(
                makeMatch,
                receivedAmt,
                feeAmt,
                royaltyFeeAmt,
                orderRight,
                orderLeft
            );
        }
    }

    function createDealSide(
        address from,
        address to,
        LibAsset.Asset memory asset
    ) internal view returns (LibDeal.DealSide memory) {
        return
            LibDeal.DealSide({
                asset: asset,
                proxy: proxies[uint8(asset.assetType)],
                from: from,
                to: to
            });
    }

    function calculateFee(
        uint256 value,
        uint256 feeAmount
    ) internal pure returns (uint256) {
        return (value * feeAmount) / 10000;
    }

    function transferAssetWithFees(
        LibAsset.Asset memory asset,
        uint256 receivedAmt,
        uint256 feeAmt,
        uint256 royaltyFeeAmt,
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal {
        transfer(
            asset,
            orderRight.maker,
            orderLeft.maker,
            proxies[uint8(asset.assetType)]
        );
        transfer(
            asset,
            orderRight.maker,
            address(this),
            proxies[uint8(asset.assetType)]
        );
        transfer(
            asset,
            orderRight.maker,
            orderLeft.royaltyFee.receiver,
            proxies[uint8(asset.assetType)]
        );
    }

    function matchAssets(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        uint256 currentFilledAmt
    )
        internal
        view
        returns (
            LibAsset.Asset memory makeMatch,
            LibAsset.Asset memory takeMatch
        )
    {
        makeMatch = matchAssets(
            orderLeft.makeAsset,
            orderRight.takeAsset,
            currentFilledAmt
        );
        require(makeMatch.assetType != 0, "assets don't match");

        takeMatch = matchAssets(
            orderLeft.takeAsset,
            orderRight.makeAsset,
            currentFilledAmt
        );
        require(takeMatch.assetType != 0, "assets don't match");
    }

    function getPaymentAssetType(
        address token
    ) internal pure returns (LibAsset.PaymentAsset memory) {
        return
            token == address(0)
                ? LibAsset.PaymentAsset(1, address(0))
                : LibAsset.PaymentAsset(2, token);
    }

    function validateFull(
        LibOrder.Order memory order,
        bytes memory signature
    ) internal view {
        LibOrder.validateOrderTime(order);

        validate(order, signature);
    }

    function validateTakeAssetAmount(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal view {
        // Retrieve the current filled amount once to avoid multiple lookups
        uint256 currentFilledAmt = cancelledOrFiledOrders[orderLeft.maker][
            orderLeft.sig
        ][orderLeft.index];

        // Check if the order is cancelled (assetType == 3)
        if (orderLeft.makeAsset.assetType == 3) {
            require(currentFilledAmt == 0, "Order has been cancelled");
        }
        // Check if the order is fulfilled (assetType == 4)
        else if (orderLeft.makeAsset.assetType == 4) {
            require(
                orderLeft.makeAsset.value >=
                    currentFilledAmt + orderRight.takeAsset.value,
                "Order has been fulfilled"
            );
        }
    }

    uint256[49] private __gap;
}

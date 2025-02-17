// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/OwnableUpgradeable.sol";
import "../contracts/AssetMatcher.sol";
import "../contracts/TransferExecutor.sol";
import "../contracts/OrderValidator.sol";
import "../contracts/library/LibDirectTransfer.sol";
import "../contracts/library/LibFill.sol";
import "../contracts/interface/ITransferManager.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract ExchangeV2Core is
    Initializable,
    OwnableUpgradeable,
    AssetMatcher,
    TransferExecutor,
    OrderValidator,
    ITransferManager,
    ReentrancyGuard
{
    using SafeMathUpgradeable for uint256;
    using LibTransfer for address;

    uint256 private constant UINT256_MAX = type(uint256).max;
    uint256 private randNonce = 0;

    // State of the orders
    mapping(bytes32 => uint256) public fills;
    mapping(address => mapping(bytes => mapping(uint16 => uint256)))
        private cancelledOrFiledOrders;

    // Events
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

    function cancelOrder(LibOrder.Order memory order) external nonReentrant {
        require(_msgSender() == order.maker, "not a maker");
        require(
            cancelledOrFiledOrders[_msgSender()][order.sig][order.index] == 0,
            "Order already canceled or filled"
        );
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

    function directAcceptBidCollection(
        LibDirectTransfer.AcceptBidCollection calldata direct
    ) external payable {
        LibOrder.BidCollectionOrder memory bidCollectionOrder = direct.bidOrder;
        LibOrder.Order memory sellOrder = direct.sellOrder;

        uint256 maxBidTakeAssetQty = bidCollectionOrder
            .bidCollectionAsset
            .value;
        uint256 acceptBidMakeAssetQty = sellOrder.makeAsset.value;

        require(
            acceptBidMakeAssetQty <= maxBidTakeAssetQty,
            "Accept bid qty higher than bid qty"
        );

        validateCollectionBidOrder(bidCollectionOrder, bidCollectionOrder.sig);
        validateFull(sellOrder, sellOrder.sig);

        uint256 bidPricePerUnit = bidCollectionOrder.makeAsset.value /
            maxBidTakeAssetQty;
        uint256 totalBidPrice = bidPricePerUnit * acceptBidMakeAssetQty;

        require(
            totalBidPrice <= bidCollectionOrder.makeAsset.value,
            "Bid ERC-20 amount not enough"
        );

        LibAsset.Asset memory makeAsset = LibAsset.Asset({
            assetType: bidCollectionOrder.makeAsset.assetType,
            contractAddress: bidCollectionOrder.makeAsset.contractAddress,
            value: bidCollectionOrder.makeAsset.value,
            id: bidCollectionOrder.makeAsset.id
        });

        LibAsset.Asset memory takeAsset = LibAsset.Asset({
            assetType: bidCollectionOrder.bidCollectionAsset.assetType,
            contractAddress: bidCollectionOrder
                .bidCollectionAsset
                .contractAddress,
            value: bidCollectionOrder.bidCollectionAsset.value,
            id: sellOrder.makeAsset.id
        });

        LibOrder.Order memory bidOrder = LibOrder.Order({
            orderType: LibOrder.OrderType.BID_COLLECTION,
            maker: bidCollectionOrder.maker,
            makeAsset: makeAsset,
            taker: sellOrder.maker,
            takeAsset: takeAsset,
            salt: bidCollectionOrder.salt,
            start: bidCollectionOrder.start,
            end: bidCollectionOrder.end,
            originFee: bidCollectionOrder.originFee,
            royaltyFee: bidCollectionOrder.royaltyFee,
            sig: bidCollectionOrder.sig,
            root: bidCollectionOrder.root,
            proof: bidCollectionOrder.proof,
            index: bidCollectionOrder.index
        });

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

            if (orderLeft.orderType == LibOrder.OrderType.BULK) {
                require(
                    validateListing(orderLeft.root, orderLeft.proof, orderLeft),
                    "Invalid listing"
                );
            }
            if (orderRight.orderType == LibOrder.OrderType.BULK) {
                require(
                    validateListing(
                        orderRight.root,
                        orderRight.proof,
                        orderRight
                    ),
                    "Invalid listing"
                );
            }

            validateTakeAssetAmount(orderLeft, orderRight);
            validateOrders(orderLeft, orderRight);
            matchAndTransfer(orderLeft, orderRight, currentFilledAmt);
        }
    }

    function validateTakeAssetAmount(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal view {
        uint256 currentFilledAmt = cancelledOrFiledOrders[orderLeft.maker][
            orderLeft.sig
        ][orderLeft.index];
        if (orderLeft.makeAsset.assetType == 3) {
            require(
                cancelledOrFiledOrders[orderLeft.maker][orderLeft.sig][
                    orderLeft.index
                ] == 0,
                "Order has been cancelled"
            );
        }
        if (orderLeft.makeAsset.assetType == 4) {
            require(
                orderLeft.makeAsset.value >=
                    currentFilledAmt + orderRight.takeAsset.value,
                "Order has been fulfilled"
            );
        }
    }

    function validateOrders(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight
    ) internal view {
        validateFull(orderLeft, orderLeft.sig);
        validateFull(orderRight, orderRight.sig);

        if (orderLeft.taker != address(0)) {
            require(
                orderRight.maker == orderLeft.taker,
                "leftOrder.taker verification failed"
            );
        }
        if (orderRight.taker != address(0)) {
            require(
                orderRight.taker == orderLeft.maker,
                "rightOrder.taker verification failed"
            );
        }

        if (
            orderLeft.makeAsset.assetType == 3 ||
            orderLeft.makeAsset.assetType == 4
        ) {
            uint256 takeQty = orderRight.takeAsset.value;
            uint256 pricePerUnit = orderLeft.takeAsset.value;
            uint256 makeValue = orderRight.makeAsset.assetType == 2
                ? orderRight.makeAsset.value
                : msg.value;

            if (orderRight.makeAsset.assetType == 2) {
                uint256 erc20Balance = IERC20Upgradeable(
                    orderRight.makeAsset.contractAddress
                ).balanceOf(orderRight.maker);
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

        if (
            orderRight.makeAsset.assetType == 3 ||
            orderRight.makeAsset.assetType == 4
        ) {
            uint256 takeQty = orderLeft.takeAsset.value;
            uint256 pricePerUnit = orderRight.takeAsset.value;
            uint256 makeValue = orderLeft.makeAsset.assetType == 2
                ? IERC20Upgradeable(orderLeft.makeAsset.contractAddress)
                    .balanceOf(orderLeft.maker)
                : msg.value;

            if (orderLeft.makeAsset.assetType == 2) {
                uint256 erc20Balance = IERC20Upgradeable(
                    orderLeft.makeAsset.contractAddress
                ).balanceOf(orderLeft.maker);
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
    }

    function matchAndTransfer(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        uint256 currentFilledAmt
    ) internal {
        (
            LibAsset.Asset memory makeMatch,
            LibAsset.Asset memory takeMatch
        ) = matchAssets(
                orderLeft,
                orderRight,
                currentFilledAmt,
                orderLeft.orderType
            );

        transferAssets(orderLeft, orderRight, makeMatch, takeMatch);

        LibOrder.Order memory makeOrder = (orderLeft.orderType ==
            LibOrder.OrderType.BID) ||
            (orderLeft.orderType == LibOrder.OrderType.BID_COLLECTION)
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
    ) internal nonReentrant {
        doTransfers(
            LibDeal.DealSide({
                asset: makeMatch,
                proxy: proxies[uint8(makeMatch.assetType)],
                from: orderLeft.maker,
                to: orderRight.maker
            }),
            LibDeal.DealSide({
                asset: takeMatch,
                proxy: proxies[uint8(takeMatch.assetType)],
                from: orderRight.maker,
                to: orderLeft.maker
            })
        );

        if (takeMatch.assetType == 1 || takeMatch.assetType == 2) {
            require(orderLeft.makeAsset.assetType != takeMatch.assetType);
            uint256 feeAmt = (takeMatch.value * orderLeft.originFee.amount) /
                10000;
            uint256 royaltyFeeAmt = (takeMatch.value *
                orderLeft.royaltyFee.amount) / 10000;
            uint256 receivedAmt = takeMatch.value - feeAmt - royaltyFeeAmt;

            transfer(
                LibAsset.Asset(
                    takeMatch.assetType,
                    takeMatch.contractAddress,
                    receivedAmt,
                    takeMatch.id
                ),
                orderRight.maker,
                orderLeft.maker,
                proxies[uint8(takeMatch.assetType)]
            );
            transfer(
                LibAsset.Asset(
                    takeMatch.assetType,
                    takeMatch.contractAddress,
                    feeAmt,
                    takeMatch.id
                ),
                orderRight.maker,
                address(this),
                proxies[uint8(takeMatch.assetType)]
            );
            transfer(
                LibAsset.Asset(
                    takeMatch.assetType,
                    takeMatch.contractAddress,
                    royaltyFeeAmt,
                    takeMatch.id
                ),
                orderRight.maker,
                orderLeft.royaltyFee.receiver,
                proxies[uint8(takeMatch.assetType)]
            );
        } else {
            require(orderRight.makeAsset.assetType != makeMatch.assetType);
            uint256 feeAmt = (makeMatch.value * orderRight.originFee.amount) /
                10000;
            uint256 royaltyFeeAmt = (makeMatch.value *
                orderRight.royaltyFee.amount) / 10000;
            uint256 receivedAmt = makeMatch.value - feeAmt - royaltyFeeAmt;

            transfer(
                LibAsset.Asset(
                    makeMatch.assetType,
                    makeMatch.contractAddress,
                    receivedAmt,
                    makeMatch.id
                ),
                orderLeft.maker,
                orderRight.maker,
                proxies[uint8(makeMatch.assetType)]
            );
            transfer(
                LibAsset.Asset(
                    makeMatch.assetType,
                    makeMatch.contractAddress,
                    feeAmt,
                    makeMatch.id
                ),
                orderLeft.maker,
                address(this),
                proxies[uint8(makeMatch.assetType)]
            );
            transfer(
                LibAsset.Asset(
                    makeMatch.assetType,
                    makeMatch.contractAddress,
                    royaltyFeeAmt,
                    makeMatch.id
                ),
                orderLeft.maker,
                orderRight.royaltyFee.receiver,
                proxies[uint8(makeMatch.assetType)]
            );
        }
    }

    function setFillEmitMatch(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        bytes32 leftOrderKeyHash,
        bytes32 rightOrderKeyHash,
        bool leftMakeFill,
        bool rightMakeFill
    ) internal returns (LibFill.FillResult memory) {
        uint256 leftOrderFill = getOrderFill(orderLeft.salt, leftOrderKeyHash);
        uint256 rightOrderFill = getOrderFill(
            orderRight.salt,
            rightOrderKeyHash
        );
        LibFill.FillResult memory newFill = LibFill.fillOrder(
            orderLeft,
            orderRight,
            leftOrderFill,
            rightOrderFill,
            leftMakeFill,
            rightMakeFill
        );

        require(
            newFill.leftValue > 0 || newFill.rightValue > 0,
            "nothing to fill"
        );

        if (orderLeft.salt != 0) {
            fills[leftOrderKeyHash] = leftOrderFill.add(
                leftMakeFill ? newFill.leftValue : newFill.rightValue
            );
        }

        if (orderRight.salt != 0) {
            fills[rightOrderKeyHash] = rightOrderFill.add(
                rightMakeFill ? newFill.rightValue : newFill.leftValue
            );
        }

        emit Match(
            leftOrderKeyHash,
            rightOrderKeyHash,
            newFill.rightValue,
            newFill.leftValue
        );

        return newFill;
    }

    function getOrderFill(
        uint256 salt,
        bytes32 hash
    ) internal view returns (uint256 fill) {
        return salt == 0 ? 0 : fills[hash];
    }

    function matchAssets(
        LibOrder.Order memory orderLeft,
        LibOrder.Order memory orderRight,
        uint256 currentFilledAmt,
        LibOrder.OrderType orderType
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
            currentFilledAmt,
            orderType
        );
        require(makeMatch.assetType != 0, "assets don't match");
        takeMatch = matchAssets(
            orderLeft.takeAsset,
            orderRight.makeAsset,
            currentFilledAmt,
            orderType
        );
        require(takeMatch.assetType != 0, "assets don't match");
    }

    function validateFull(
        LibOrder.Order memory order,
        bytes memory signature
    ) internal view {
        LibOrder.validateOrderTime(order);
        validate(order, signature);
    }

    function getPaymentAssetType(
        address token
    ) internal pure returns (LibAsset.PaymentAsset memory) {
        return
            LibAsset.PaymentAsset({
                assetType: int8(token == address(0) ? 1 : 2),
                contractAddress: token
            });
    }

    uint256[49] private __gap;
}

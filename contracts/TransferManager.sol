// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/OwnableUpgradeable.sol";
import "../contracts/interface/ITransferManager.sol";
import "../contracts/interface/IRoyaltiesProvider.sol";
import "../contracts/library/BpLibrary.sol";

abstract contract TransferManager is
    OwnableUpgradeable,
    ITransferManager
{
    using BpLibrary for uint256;
    using SafeMathUpgradeable for uint256;

    ProtocolFeeData public protocolFee;
    IRoyaltiesProvider public royaltiesRegistry;

    //deprecated
    address private defaultFeeReceiver;
    // deprecated
    mapping(address => address) private feeReceivers;

    /// @dev event that's emitted when ProtocolFeeData buyerAmount changes
    event BuyerFeeAmountChanged(uint256 oldValue, uint256 newValue);

    /// @dev event that's emitted when ProtocolFeeData sellerAmount changes
    event SellerFeeAmountChanged(uint256 oldValue, uint256 newValue);

    /// @dev event that's emitted when ProtocolFeeData receiver changes
    event FeeReceiverChanged(address oldValue, address newValue);

    /// @dev struct to store protocol fee - receiver address, buyer fee amount (in bp), seller fee amount (in bp)
    struct ProtocolFeeData {
        address receiver;
        uint48 buyerAmount;
        uint48 sellerAmount;
    }

    /**
        @notice initialises RaribleTransferManager state
        @param newProtocolFee deprecated
        @param newDefaultFeeReceiver deprecated
        @param newRoyaltiesProvider royaltiesRegistry contract address
     */
    function __RaribleTransferManager_init_unchained(
        uint256 newProtocolFee,
        address newDefaultFeeReceiver,
        IRoyaltiesProvider newRoyaltiesProvider
    ) internal initializer {
        royaltiesRegistry = newRoyaltiesProvider;
    }

    function setRoyaltiesRegistry(IRoyaltiesProvider newRoyaltiesRegistry)
        external
        onlyOwner
    {
        royaltiesRegistry = newRoyaltiesRegistry;
    }

    function setPrtocolFeeReceiver(address _receiver) public onlyOwner {
        emit FeeReceiverChanged(protocolFee.receiver, _receiver);
        protocolFee.receiver = _receiver;
    }

    function setPrtocolFeeBuyerAmount(uint48 _buyerAmount) public onlyOwner {
        emit BuyerFeeAmountChanged(protocolFee.buyerAmount, _buyerAmount);
        protocolFee.buyerAmount = _buyerAmount;
    }

    function setPrtocolFeeSellerAmount(uint48 _sellerAmount) public onlyOwner {
        emit SellerFeeAmountChanged(protocolFee.sellerAmount, _sellerAmount);
        protocolFee.sellerAmount = _sellerAmount;
    }

    function setAllProtocolFeeData(
        address _receiver,
        uint48 _buyerAmount,
        uint48 _sellerAmount
    ) public onlyOwner {
        setPrtocolFeeReceiver(_receiver);
        setPrtocolFeeBuyerAmount(_buyerAmount);
        setPrtocolFeeSellerAmount(_sellerAmount);
    }

    /**
        @notice executes transfers for 2 matched orders
        @param left DealSide from the left order (see LibDeal.sol)
        @param right DealSide from the right order (see LibDeal.sol)
        @return totalLeftValue - total amount for the left order
        @return totalRightValue - total amout for the right order
    */
    function doTransfers(
        LibDeal.DealSide memory left,
        LibDeal.DealSide memory right
    )
        internal
        override
        returns (
            // LibFeeSide.FeeSide feeSide
            uint256 totalLeftValue,
            uint256 totalRightValue
        )
    {
        totalLeftValue = left.asset.value;
        totalRightValue = right.asset.value;
        if (left.asset.assetType == 3 || left.asset.assetType == 4) {
            transfer(left.asset, left.from, left.to, left.proxy);
        }
        if (right.asset.assetType == 3 || right.asset.assetType == 4) {
            transfer(right.asset, right.from, right.to, right.proxy);
        }
    }

    /**
        @notice transfers protocol fee to protocol fee receiver
    */
    // function transferProtocolFee(
    //     uint totalAmount,
    //     uint amount,
    //     address from,
    //     uint protocolFeeTotal,
    //     address protocolFeeReceiver,
    //     LibAsset.Asset memory matchCalculate,
    //     address proxy
    // ) internal returns (uint) {
    //     (uint rest, uint fee) = subFeeInBp(
    //         totalAmount,
    //         amount,
    //         protocolFeeTotal
    //     );
    //     if (fee > 0) {
    //         transfer(
    //             LibAsset.Asset(matchCalcul),
    //             from,
    //             protocolFeeReceiver,
    //             proxy
    //         );
    //     }
    //     return rest;
    // }

    /**
        @notice Transfer royalties. If there is only one royalties receiver and one address in payouts and they match,
           nothing is transferred in this function
        @param paymentAssetType Asset Type which represents payment
        @param nftAssetType Asset Type which represents NFT to pay royalties for
        @param payouts Payouts to be made
        @param rest How much of the amount left after previous transfers
        @param from owner of the Asset to transfer
        @param proxy Transfer proxy to use
        @return How much left after transferring royalties
    */
    // function transferRoyalties(
    //     LibAsset.AssetType memory paymentAssetType,
    //     LibAsset.AssetType memory nftAssetType,
    //     LibPart.Part[] memory payouts,
    //     uint rest,
    //     uint amount,
    //     address from,
    //     address proxy
    // ) internal returns (uint) {
    //     LibPart.Part[] memory royalties = getRoyaltiesByAssetType(nftAssetType);
    //     if (
    //         royalties.length == 1 &&
    //         payouts.length == 1 &&
    //         royalties[0].account == payouts[0].account
    //     ) {
    //         require(
    //             royalties[0].value <= 5000,
    //             "Royalties are too high (>50%)"
    //         );
    //         return rest;
    //     }
    //     (uint result, uint totalRoyalties) = transferFees(
    //         paymentAssetType,
    //         rest,
    //         amount,
    //         royalties,
    //         from,
    //         proxy
    //     );
    //     require(totalRoyalties <= 5000, "Royalties are too high (>50%)");
    //     return result;
    // }

    /**
        @notice calculates royalties by asset type. If it's a lazy NFT, then royalties are extracted from asset. otherwise using royaltiesRegistry
        @param nftAssetType NFT Asset Type to calculate royalties for
        @return calculated royalties (Array of LibPart.Part)
    */
    // function getRoyaltiesByAssetType(
    //     LibAsset.AssetType memory nftAssetType
    // ) internal returns (LibPart.Part[] memory) {
    //     if (
    //         nftAssetType.assetClass == LibAsset.ERC1155_ASSET_CLASS ||
    //         nftAssetType.assetClass == LibAsset.ERC721_ASSET_CLASS
    //     ) {
    //         (address token, uint tokenId) = abi.decode(
    //             nftAssetType.data,
    //             (address, uint)
    //         );
    //         return royaltiesRegistry.getRoyalties(token, tokenId);
    //     } else if (
    //         nftAssetType.assetClass ==
    //         LibERC1155LazyMint.ERC1155_LAZY_ASSET_CLASS
    //     ) {
    //         (, LibERC1155LazyMint.Mint1155Data memory data) = abi.decode(
    //             nftAssetType.data,
    //             (address, LibERC1155LazyMint.Mint1155Data)
    //         );
    //         return data.royalties;
    //     } else if (
    //         nftAssetType.assetClass == LibERC721LazyMint.ERC721_LAZY_ASSET_CLASS
    //     ) {
    //         (, LibERC721LazyMint.Mint721Data memory data) = abi.decode(
    //             nftAssetType.data,
    //             (address, LibERC721LazyMint.Mint721Data)
    //         );
    //         return data.royalties;
    //     }
    //     LibPart.Part[] memory empty;
    //     return empty;
    // }

    /**
        @notice Transfer fees
        @param assetType Asset Type to transfer
        @param rest How much of the amount left after previous transfers
        @param amount Total amount of the Asset. Used as a base to calculate part from (100%)
        @param fees Array of LibPart.Part which represents fees to pay
        @param from owner of the Asset to transfer
        @param proxy Transfer proxy to use
        @return newRest how much left after transferring fees
        @return totalFees total number of fees in bp
    */
    // function transferFees(
    //     LibAsset.AssetType memory assetType,
    //     uint rest,
    //     uint amount,
    //     LibPart.Part[] memory fees,
    //     address from,
    //     address proxy
    // ) internal returns (uint newRest, uint totalFees) {
    //     totalFees = 0;
    //     newRest = rest;
    //     for (uint256 i = 0; i < fees.length; ++i) {
    //         totalFees = totalFees.add(fees[i].value);
    //         uint feeValue;
    //         (newRest, feeValue) = subFeeInBp(newRest, amount, fees[i].value);
    //         if (feeValue > 0) {
    //             transfer(
    //                 LibAsset.Asset(assetType, feeValue),
    //                 from,
    //                 fees[i].account,
    //                 proxy
    //             );
    //         }
    //     }
    // }

    /**
        @notice transfers main part of the asset (payout)
        @param asset Asset Type to transfer
        @param from Current owner of the asset
        @param proxy Transfer Proxy to use
    */
    function transferPayouts(
        LibAsset.Asset memory asset,
        address from,
        address to,
        // LibPart.Part[] memory payouts,
        address proxy
    ) internal {
        transfer(asset, from, to, proxy);
        // require(payouts.length > 0, "transferPayouts: nothing to transfer");
        // uint defaultVal = 0;
        // uint sumBps = 0;
        // uint rest = amount;
        // for (uint256 i = 0; i < payouts.length - 1; ++i) {
        //     uint currentAmount = amount.bp(payouts[i].value);
        //     sumBps = sumBps.add(payouts[i].value);
        //     if (currentAmount > 0) {
        //         rest = rest.sub(currentAmount);
        //         transfer(
        //             LibAsset.Asset(
        //                 asset.assetType,
        //                 asset.contractAddress,
        //                 currentAmount,
        //                 defaultVal
        //             ),
        //             from,
        //             payouts[i].account,
        //             proxy
        //         );
        //     }
        // }
        // LibPart.Part memory lastPayout = payouts[payouts.length - 1];
        // sumBps = sumBps.add(lastPayout.value);
        // require(sumBps == 10000, "Sum payouts Bps not equal 100%");
        // if (rest > 0) {
        //     transfer(
        //         LibAsset.Asset(
        //             asset.assetType,
        //             asset.contractAddress,
        //             rest,
        //             defaultVal
        //         ),
        //         from,
        //         lastPayout.account,
        //         proxy
        //     );
        // }
    }

    /**
        @notice calculates total amount of fee-side asset that is going to be used in match
        @param amount fee-side order value
        @param buyerProtocolFee buyer protocol fee
        @param orderOriginFees fee-side order's origin fee (it adds on top of the amount)
        @return total amount of fee-side asset
    */
    function calculateTotalAmount(
        uint256 amount,
        uint256 buyerProtocolFee,
        LibPart.Part[] memory orderOriginFees
    ) internal pure returns (uint256) {
        uint256 fees = buyerProtocolFee;
        for (uint256 i = 0; i < orderOriginFees.length; ++i) {
            require(orderOriginFees[i].value <= 10000, "origin fee is too big");
            fees = fees + orderOriginFees[i].value;
        }

        return amount.add(amount.bp(fees));
    }

    function subFeeInBp(
        uint256 value,
        uint256 total,
        uint256 feeInBp
    ) internal pure returns (uint256 newValue, uint256 realFee) {
        return subFee(value, total.bp(feeInBp));
    }

    function subFee(uint256 value, uint256 fee)
        internal
        pure
        returns (uint256 newValue, uint256 realFee)
    {
        if (value > fee) {
            newValue = value.sub(fee);
            realFee = fee;
        } else {
            newValue = 0;
            realFee = value;
        }
    }

    uint256[46] private __gap;
}

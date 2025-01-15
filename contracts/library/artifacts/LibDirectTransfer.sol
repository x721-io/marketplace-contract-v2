// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../../library/LibOrder.sol";

library LibDirectTransfer {
    //LibDirectTransfers
    /*All buy parameters need for create buyOrder and sellOrder*/
    struct Purchase {
        address sellOrderMaker; //
        uint256 sellOrderNftAmount;
        bytes4 nftAssetClass;
        bytes nftData;
        uint256 sellOrderPaymentAmount;
        address paymentToken;
        uint256 sellOrderSalt;
        uint256 sellOrderStart;
        uint256 sellOrderEnd;
        bytes4 sellOrderDataType;
        bytes sellOrderData;
        bytes sellOrderSignature;
        uint256 buyOrderPaymentAmount;
        uint256 buyOrderNftAmount;
        bytes buyOrderData;
    }

    /*All accept bid parameters need for create buyOrder and sellOrder*/
    struct AcceptBid {
        LibOrder.Order bidOrder;
        LibOrder.Order sellOrder;
    }
}

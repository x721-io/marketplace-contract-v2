// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../../contracts/interface/ITransferExecutor.sol";
import "../../contracts/library/LibDeal.sol";

abstract contract ITransferManager is ITransferExecutor {
    function doTransfers(
        LibDeal.DealSide memory left,
        LibDeal.DealSide memory right
    )
        internal
        virtual
        returns (
            // LibFeeSide.FeeSide feeSide
            uint256 totalMakeValue,
            uint256 totalTakeValue
        );
}

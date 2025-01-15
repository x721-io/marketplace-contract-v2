// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/OwnableUpgradeable.sol";
import "../contracts/AssetMatcher.sol";
import "../contracts/TransferExecutor.sol";
import "../contracts/TransferManager.sol";
import "../contracts/ExchangeV2Core.sol";
import "../contracts/OrderValidator.sol";
import "../contracts/library/LibPart.sol";
import "../contracts/library/LibDirectTransfer.sol";
import "../contracts/library/LibFill.sol";
import "../contracts/interface/ITransferManager.sol";

library LibOrderDataV1 {
    bytes4 public constant V1 = bytes4(keccak256("V1"));

    struct DataV1 {
        LibPart.Part[] payouts;
        LibPart.Part[] originFees;
    }
}

library LibOrderDataV2 {
    bytes4 public constant V2 = bytes4(keccak256("V2"));

    struct DataV2 {
        LibPart.Part[] payouts;
        LibPart.Part[] originFees;
        bool isMakeFill;
    }
}

library LibOrderDataV3 {
    bytes4 public constant V3 = bytes4(keccak256("V3"));

    struct DataV3 {
        LibPart.Part[] payouts;
        LibPart.Part[] originFees;
        bool isMakeFill;
    }
}

// library LibFeeSide {
//     enum FeeSide {
//         NONE,
//         LEFT,
//         RIGHT
//     }

//     function getFeeSide(
//         bytes4 leftClass,
//         bytes4 rightClass
//     ) internal pure returns (FeeSide) {
//         if (leftClass == LibAsset.ETH_ASSET_CLASS) {
//             return FeeSide.LEFT;
//         }
//         if (rightClass == LibAsset.ETH_ASSET_CLASS) {
//             return FeeSide.RIGHT;
//         }
//         if (leftClass == LibAsset.ERC20_ASSET_CLASS) {
//             return FeeSide.LEFT;
//         }
//         if (rightClass == LibAsset.ERC20_ASSET_CLASS) {
//             return FeeSide.RIGHT;
//         }
//         if (leftClass == LibAsset.ERC1155_ASSET_CLASS) {
//             return FeeSide.LEFT;
//         }
//         if (rightClass == LibAsset.ERC1155_ASSET_CLASS) {
//             return FeeSide.RIGHT;
//         }
//         return FeeSide.NONE;
//     }
// }

contract ExchangeV2 is ExchangeV2Core, TransferManager {
    constructor() {
        _owner = msg.sender;
        __OrderValidator_init_unchained();
    }

    function __ExchangeV2_init(
        address _transferProxy,
        address _erc20TransferProxy,
        uint256 newProtocolFee,
        address newDefaultFeeReceiver,
        IRoyaltiesProvider newRoyaltiesProvider
    ) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __TransferExecutor_init_unchained(_transferProxy, _erc20TransferProxy);
        __RaribleTransferManager_init_unchained(
            newProtocolFee,
            newDefaultFeeReceiver,
            newRoyaltiesProvider
        );
    }
}
        
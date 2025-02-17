// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/OwnableUpgradeable.sol";
import "../contracts/interface/IAssetMatcher.sol";
import "../contracts/library/LibOrder.sol";

abstract contract AssetMatcher is Initializable, OwnableUpgradeable {
    bytes constant EMPTY = "";
    mapping(uint256 => address) internal matchers;

    event MatcherChange(uint256 indexed assetType, address matcher);

    function setAssetMatcher(
        uint256 assetType,
        address matcher
    ) external onlyOwner {
        matchers[assetType] = matcher;
        emit MatcherChange(assetType, matcher);
    }

    function matchAssets(
        LibAsset.Asset memory leftAsset,
        LibAsset.Asset memory rightAsset,
        uint256 currentFilledAmt,
        LibOrder.OrderType orderType
    ) internal view returns (LibAsset.Asset memory) {
        LibAsset.Asset memory result = matchAssetOneSide(
            leftAsset,
            rightAsset,
            currentFilledAmt,
            orderType
        );
        if (result.assetType == 1) {
            return
                matchAssetOneSide(
                    rightAsset,
                    leftAsset,
                    currentFilledAmt,
                    orderType
                );
        } else {
            return result;
        }
    }

    function matchAssetOneSide(
        LibAsset.Asset memory leftAsset,
        LibAsset.Asset memory rightAsset,
        uint256 currentFilledAmt,
        LibOrder.OrderType orderType
    ) private view returns (LibAsset.Asset memory) {
        uint256 defaultValue = 0;
        address zeroAddress = 0x0000000000000000000000000000000000000000;
        if (leftAsset.assetType == 1) {
            if (rightAsset.assetType == 1) {
                return leftAsset;
            }
            return LibAsset.Asset(0, zeroAddress, defaultValue, defaultValue);
        }
        if (leftAsset.assetType == 2) {
            if (rightAsset.assetType == 2) {
                return simpleMatch(leftAsset, rightAsset, orderType);
            }
            return LibAsset.Asset(0, zeroAddress, defaultValue, defaultValue);
        }
        if (leftAsset.assetType == 3) {
            if (rightAsset.assetType == 3) {
                return simpleMatch(leftAsset, rightAsset, orderType);
            }
            return LibAsset.Asset(0, zeroAddress, defaultValue, defaultValue);
        }
        if (leftAsset.assetType == 4) {
            if (rightAsset.assetType == 4) {
                return matchERC1155(leftAsset, rightAsset, currentFilledAmt);
            }
            return LibAsset.Asset(0, zeroAddress, defaultValue, defaultValue);
        }
        address matcher = matchers[uint256(leftAsset.assetType)];
        if (matcher != address(0)) {
            return IAssetMatcher(matcher).matchAssets(leftAsset, rightAsset);
        }
        if (leftAsset.assetType == rightAsset.assetType) {
            return simpleMatch(leftAsset, rightAsset, orderType);
        }
        revert("not found IAssetMatcher");
    }

    function simpleMatch(
        LibAsset.Asset memory leftAsset,
        LibAsset.Asset memory rightAsset,
        LibOrder.OrderType orderType
    ) private pure returns (LibAsset.Asset memory) {
        uint256 defaultValue = 0;
        address zeroAddress = 0x0000000000000000000000000000000000000000;

        if (leftAsset.assetType == rightAsset.assetType) {
            if (
                orderType != LibOrder.OrderType.BID_COLLECTION ||
                leftAsset.assetType != 3
            ) {
                if (leftAsset.value == rightAsset.value) {
                    return leftAsset;
                }
            } else {
                return leftAsset;
            }
        }

        return LibAsset.Asset(1, zeroAddress, defaultValue, defaultValue);
    }

    function matchERC1155(
        LibAsset.Asset memory leftAsset,
        LibAsset.Asset memory rightAsset,
        uint256 currentFilledAmt
    ) private pure returns (LibAsset.Asset memory) {
        uint256 defaultValue = 0;
        address zeroAddress = 0x0000000000000000000000000000000000000000;
        if (leftAsset.assetType == 4) {
            if (
                leftAsset.assetType == rightAsset.assetType &&
                leftAsset.value >= currentFilledAmt + rightAsset.value
            ) {
                return rightAsset;
            }
        }
        return LibAsset.Asset(0, zeroAddress, defaultValue, defaultValue);
    }

    uint256[49] private __gap;
}

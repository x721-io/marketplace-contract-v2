// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../../contracts/library/LibAsset.sol";

interface IAssetMatcher {
    function matchAssets(
        LibAsset.Asset memory leftAssetType,
        LibAsset.Asset memory rightAssetType
    ) external view returns (LibAsset.Asset memory);
}
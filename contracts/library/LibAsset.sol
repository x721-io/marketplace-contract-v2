// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

library LibAsset {
    // enum AssetType {
    //     ERROR,
    //     U2U,
    //     ERC20,
    //     ERC721,
    //     ERC1155
    // }

    struct PaymentAsset {
        int8 assetType;
        address contractAddress;
    }

    struct Asset {
        uint8 assetType;
        address contractAddress;
        uint256 value;
        uint256 id;
    }

    struct CollectionAsset {
        uint8 assetType;
        address contractAddress;
        uint256 value;
    }

    function hash(Asset memory asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(asset.assetType, asset.value));
    }

    function hashAssetV2(Asset memory asset) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "Asset(uint8 assetType,address contractAddress,uint256 value,uint256 id)"
                    ),
                    asset.assetType,
                    asset.contractAddress,
                    asset.value,
                    asset.id
                )
            );
    }

    function hashCollectionAssetV2(
        Asset memory asset
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "Asset(uint8 assetType,address contractAddress,uint256 value,uint256 id)"
                    ),
                    asset.assetType,
                    asset.contractAddress,
                    asset.value,
                    asset.id
                )
            );
    }
}

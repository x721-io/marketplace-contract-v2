// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../contracts/Initializable.sol";
import "../contracts/OwnableUpgradeable.sol";
import "../contracts/MerkleProof.sol";
import "../contracts/library/LibTransfer.sol";
import "../contracts/library/LibOrder.sol";
import "../contracts/interface/ITransferExecutor.sol";
import "../contracts/interface/IERC721Upgradeable.sol";
import "../contracts/interface/IERC20Upgradeable.sol";
import "../contracts/interface/IERC20TransferProxy.sol";
import "../contracts/interface/INftTransferProxy.sol";
import "../contracts/interface/ITransferProxy.sol";

abstract contract TransferExecutor is
    Initializable,
    OwnableUpgradeable,
    ITransferExecutor
{
    using LibTransfer for address;

    mapping(uint8 => address) internal proxies;

    event ProxyChange(uint256 indexed assetType, address proxy);

    function __TransferExecutor_init_unchained(
        address transferProxy,
        address erc20TransferProxy
    ) internal {
        proxies[uint8(2)] = address(erc20TransferProxy);
        proxies[uint8(3)] = address(transferProxy);
        proxies[uint8(4)] = address(transferProxy);
    }

    function getTransferProxy(uint8 index) external view returns (address) {
        return proxies[index];
    }

    function setTransferProxy(uint8 index, address proxy) external onlyOwner {
        proxies[index] = proxy;
        emit ProxyChange(index, proxy);
    }

    function transfer(
        LibAsset.Asset memory asset,
        address from,
        address to,
        address proxy
    ) internal override {
        if (asset.assetType == 3) {
            //not using transfer proxy when transfering from this contract
            require(asset.value == 1, "erc721 value error");
            if (from == address(this)) {
                IERC721Upgradeable(asset.contractAddress).safeTransferFrom(
                    address(this),
                    to,
                    asset.id
                );
            } else {
                INftTransferProxy(proxy).erc721safeTransferFrom(
                    IERC721Upgradeable(asset.contractAddress),
                    from,
                    to,
                    asset.id
                );
            }
        } else if (asset.assetType == 2) {
            //not using transfer proxy when transfering from this contract
            if (from == address(this)) {
                require(
                    IERC20Upgradeable(asset.contractAddress).transfer(
                        to,
                        asset.value
                    ),
                    "erc20 transfer failed"
                );
            } else {
                IERC20TransferProxy(proxy).erc20safeTransferFrom(
                    IERC20Upgradeable(asset.contractAddress),
                    from,
                    to,
                    asset.value
                );
            }
            // require(
            //     IERC20Upgradeable(asset.contractAddress).transfer(
            //         to,
            //         asset.value
            //     ),
            //     "erc20 transfer failed"
            // );
        } else if (asset.assetType == 4) {
            //not using transfer proxy when transfering from this contract
            if (from == address(this)) {
                IERC1155Upgradeable(asset.contractAddress).safeTransferFrom(
                    address(this),
                    to,
                    asset.id,
                    asset.value,
                    ""
                );
            } else {
                INftTransferProxy(proxy).erc1155safeTransferFrom(
                    IERC1155Upgradeable(asset.contractAddress),
                    from,
                    to,
                    asset.id,
                    asset.value,
                    ""
                );
            }
        } else if (asset.assetType == 1) {
            if (to != address(this)) {
                to.transferEth(asset.value);
            }
        } else {
            ITransferProxy(proxy).transfer(asset, from, to);
        }
    }

    uint256[49] private __gap;

    function validateListing(
        bytes32 root,
        bytes32[] memory proof,
        LibOrder.Order memory order
    ) public pure returns (bool isValid) {
        bytes32 hashLeaf = LibOrder.hashMerkleLeaf(order);
        isValid = MerkleProof.verify(proof, root, hashLeaf);
    }
}

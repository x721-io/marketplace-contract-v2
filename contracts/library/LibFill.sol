// SPDX-License-Identifier: MIT
pragma solidity <0.8.0 =0.7.6 >=0.4.24 >=0.6.0 >=0.6.2 >=0.6.9 ^0.7.0;
pragma abicoder v2;

import "../../contracts/library/LibOrder.sol";

library LibFill {
    struct FillResult {
        uint256 leftValue;
        uint256 rightValue;
    }

    struct IsMakeFill {
        bool leftMake;
        bool rightMake;
    }

    /**
     * @dev Should return filled values
     * @param leftOrder left order
     * @param rightOrder right order
     * @param leftOrderFill current fill of the left order (0 if order is unfilled)
     * @param rightOrderFill current fill of the right order (0 if order is unfilled)
     * @param leftIsMakeFill true if left orders fill is calculated from the make side, false if from the take side
     * @param rightIsMakeFill true if right orders fill is calculated from the make side, false if from the take side
     * @return tuple representing fill of both assets
     */
    function fillOrder(
        LibOrder.Order memory leftOrder,
        LibOrder.Order memory rightOrder,
        uint256 leftOrderFill,
        uint256 rightOrderFill,
        bool leftIsMakeFill,
        bool rightIsMakeFill
    ) internal pure returns (FillResult memory) {
        (uint256 leftMakeValue, uint256 leftTakeValue) = LibOrder
            .calculateRemaining(leftOrder, leftOrderFill, leftIsMakeFill);
        (uint256 rightMakeValue, uint256 rightTakeValue) = LibOrder
            .calculateRemaining(rightOrder, rightOrderFill, rightIsMakeFill);

        //We have 3 cases here:
        if (
            rightTakeValue > leftMakeValue ||
            (rightTakeValue == leftMakeValue && leftMakeValue == 0)
        ) {
            //1nd: left order should be fully filled
            return
                fillLeft(
                    leftMakeValue,
                    leftTakeValue,
                    rightOrder.makeAsset.value,
                    rightOrder.takeAsset.value
                );
        } //2st: right order should be fully filled or 3d: both should be fully filled if required values are the same
        return
            fillRight(
                leftOrder.makeAsset.value,
                leftOrder.takeAsset.value,
                rightMakeValue,
                rightTakeValue
            );
    }

    function fillRight(
        uint256 leftMakeValue,
        uint256 leftTakeValue,
        uint256 rightMakeValue,
        uint256 rightTakeValue
    ) internal pure returns (FillResult memory result) {
        uint256 makerValue = LibMath.safeGetPartialAmountFloor(
            rightTakeValue,
            leftMakeValue,
            leftTakeValue
        );
        require(makerValue <= rightMakeValue, "fillRight: unable to fill");
        return FillResult(rightTakeValue, makerValue);
    }

    function fillLeft(
        uint256 leftMakeValue,
        uint256 leftTakeValue,
        uint256 rightMakeValue,
        uint256 rightTakeValue
    ) internal pure returns (FillResult memory result) {
        uint256 rightTake = LibMath.safeGetPartialAmountFloor(
            leftTakeValue,
            rightMakeValue,
            rightTakeValue
        );
        require(rightTake <= leftMakeValue, "fillLeft: unable to fill");
        return FillResult(leftMakeValue, leftTakeValue);
    }
}

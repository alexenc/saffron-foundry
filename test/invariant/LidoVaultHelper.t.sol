// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../src/contracts/LidoVault.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LidoVaultHelper is Test {
    LidoVault public lidoVault;
    address[4] public operators;

    constructor(address _lidoVault) {
        lidoVault = LidoVault(payable(_lidoVault));
        initializeOperators();
    }

    function deposit(uint256 side, uint256 _amount) external payable {
        if (lidoVault.isStarted()) return;
        side = bound(side, 0, 1);

        if (side == 0) {
            uint256 currentClaims = lidoVault.fixedETHDepositTokenTotalSupply();
            uint256 remainingCapacity = lidoVault.fixedSideCapacity() -
                currentClaims;
            uint256 minFixedDeposit = (lidoVault.fixedSideCapacity() *
                lidoVault.minimumFixedDepositBps()) / 10000;
            if (remainingCapacity <= minFixedDeposit) {
                _amount = remainingCapacity;
            } else {
                uint256 threshold = minFixedDeposit * 7;
                if (remainingCapacity <= threshold) {
                    _amount = remainingCapacity;
                } else {
                    _amount = bound(
                        _amount,
                        minFixedDeposit,
                        remainingCapacity
                    );
                }
            }
        } else {
            uint256 currentVariableDeposits = lidoVault
                .variableBearerTokenTotalSupply();
            uint256 remainingCapacity = lidoVault.variableSideCapacity() -
                currentVariableDeposits;
            uint256 minVariableDeposit = lidoVault.minimumDepositAmount();
            if (remainingCapacity <= minVariableDeposit) {
                _amount = remainingCapacity;
            } else {
                uint256 threshold = minVariableDeposit * 7;
                if (remainingCapacity <= threshold) {
                    _amount = remainingCapacity;
                } else {
                    _amount = bound(
                        _amount,
                        minVariableDeposit,
                        remainingCapacity
                    );
                }
            }
        }

        address operator = getRandomOperator(false);
        vm.startPrank(operator);
        vm.deal(operator, _amount + 0.01 ether);

        lidoVault.deposit{value: _amount}(side);
        vm.stopPrank();
    }

    function claimFixedPremium() external {
        if (!lidoVault.isStarted()) return;
        address operator = getRandomOperator(false);
        if (lidoVault.fixedClaimToken(operator) <= 0) return;
        vm.prank(operator);
        lidoVault.claimFixedPremium();
    }

    function withdraw(uint256 side) external {
        address operator;
        if (lidoVault.isStarted()) operator = getRandomOperator(true);
        else operator = getRandomOperator(false);

        side = bound(side, 0, 1);
        if (side == 0) {
            if (lidoVault.fixedBearerToken(operator) == 0) return;
        } else {
            if (lidoVault.variableBearerToken(operator) == 0) return;
        }
        vm.prank(operator);
        lidoVault.withdraw(side);
    }

    function getRandomOperator(bool isOngoing) internal returns (address) {
        if (isOngoing) return operators[0]; // in ongoing only withdraw with one operator to be able to reach end state
        uint256 randomIndex;
        bound(randomIndex, 0, 3);
        return operators[randomIndex];
    }

    function initializeOperators() internal {
        operators[0] = makeAddr("operator1");
        operators[1] = makeAddr("operator2");
        operators[2] = makeAddr("operator3");
        operators[3] = makeAddr("operator4");
    }
}

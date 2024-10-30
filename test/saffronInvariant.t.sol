// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, StdInvariant, console} from "forge-std/Test.sol";
import "../src/contracts/LidoVault.sol";
import "../src/contracts/interfaces/ILido.sol";
import "../src/contracts/interfaces/ILidoWithdrawalQueueERC721.sol";
import {ILidoVaultInitializer} from "../src/contracts/interfaces/ILidoVaultInitializer.sol";
import {MockLido} from "../src/contracts/mocks/MockLido.sol";
import {MockLidoWithdrawalQueue} from "../src/contracts/mocks/MockLidoWithdrawalQueue.sol";
import "./invariant/LidoVaultHelper.t.sol";
import "./invariant/TimeWarper.t.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LidoVaultTest is StdInvariant, Test {
    LidoVault public lidoVault;
    ILido public lido;
    ILidoWithdrawalQueueERC721 public withdrawalQueue;
    IERC20 public stETH;

    address public constant LIDO_ADDRESS =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WITHDRAWAL_QUEUE_ADDRESS =
        0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant DURATION = 30 days;
    uint256 public constant FIXED_CAPACITY = 100 ether;
    uint256 public constant VARIABLE_CAPACITY = 50 ether;
    uint256 public constant PROTOCOL_FEE_BPS = 100; // 1%
    uint256 public constant EARLY_EXIT_FEE_BPS = 1000; // 10%

    function setUp() public {
        owner = makeAddr("owner");
        MockLido mockLido = new MockLido();
        MockLidoWithdrawalQueue mockWithdrawalQueue = new MockLidoWithdrawalQueue();
        vm.etch(LIDO_ADDRESS, address(mockLido).code);
        vm.etch(WITHDRAWAL_QUEUE_ADDRESS, address(mockWithdrawalQueue).code);

        MockLido(payable(LIDO_ADDRESS)).initialize();
        MockLidoWithdrawalQueue(payable(WITHDRAWAL_QUEUE_ADDRESS)).initialize(
            address(mockLido)
        );

        lidoVault = new LidoVault(false);

        ILidoVaultInitializer.InitializationParams
            memory initializeParams = ILidoVaultInitializer
                .InitializationParams({
                    vaultId: 1,
                    duration: DURATION,
                    fixedSideCapacity: FIXED_CAPACITY,
                    variableSideCapacity: VARIABLE_CAPACITY,
                    earlyExitFeeBps: EARLY_EXIT_FEE_BPS,
                    protocolFeeBps: PROTOCOL_FEE_BPS,
                    protocolFeeReceiver: owner
                });

        lidoVault.initialize(initializeParams);

        TimeWarper timewarper = new TimeWarper();

        bytes4[] memory timeWarperSelectors = new bytes4[](1);
        timeWarperSelectors[0] = TimeWarper.warpTime.selector;

        targetSelector(
            FuzzSelector({
                addr: address(timewarper),
                selectors: timeWarperSelectors
            })
        );
        targetContract(address(timewarper));

        LidoVaultHelper helper = new LidoVaultHelper(address(lidoVault));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = LidoVaultHelper.deposit.selector;
        selectors[1] = LidoVaultHelper.claimFixedPremium.selector;
        selectors[2] = LidoVaultHelper.withdraw.selector;

        targetSelector(
            FuzzSelector({addr: address(helper), selectors: selectors})
        );
        targetContract(address(helper));
    }

    function invariant_vault() public {
        console.log(
            lidoVault.fixedBearerTokenTotalSupply(),
            "f bearer total Supply"
        );
        console.log(
            lidoVault.variableBearerTokenTotalSupply(),
            "v bearer supply"
        );

        console.log(lidoVault.isStarted(), "started");
    }
}

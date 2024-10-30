## GOALS

- re read all core functions and explain them
- make report about the dos frontRun
- re read all audit tags

## Notes

LIDO BASIC EXPLANATION
lido allows liquid staking on ehtereum, a user lock eth in the system and gets stEth back (erc20 rebasing token), there's also wstEth wich in non rebasing token. when rebasing happens user supplies of stETH this internal accounting occurs due to the shares a user has balanceOf(account) = shares[account] \* totalPooledEther / totalShares.

saffron
a vault its an agreement bwteen fixed and variable parts upon interest lock time etc

### deposit()

on fixed side deposit eth its deposited to lido vault gets stEth back and internal user accounting state its updated `fixedClaimToken` == `LIDO:submit -> shares`, `fixedETHDepositToken`: that represents msg.value of user. once vault is started fixed users can claim claimFixedPremium to get ther fixed premium.

on variable side deposit vault receives eth and mints internal accounting token to user [variableBearerToken], this token entitles owner to a portion of vault earnings.
when max capacity of both fixed and variable side its reached the vault its started

### withdraw()

Withdraw function its where everythig happens, there are different execution flows depending of the side and the vault state.

for fixed side when vault has not started if user has not a withdrawal request from lido he can claim back his ETH by requesting the withdrawal of their `stETH` shares to the lido vault that is kept track by the `fixedToVaultNotStartedWithdrawalRequestIds` mapping, requesting back eth from lido and updating internal balances.

for variable side not request its needed the user gets back eth in proportion 1-1 of his variableBearerToken.

If vault its ongoing (started but not finished)
for fixed side: requires for user to not have ongoingWithdrawal request or notStarted request, also its requested for user to have caimed its fixed premium calling claimFixedPremium and getting fixedBearerTokens. the withdraw amount its obtained by (fixedstEthVaultDeposits \* fixedBearerTokenUSer / fixedBearerTokenTotalSupply + fixedClaimTokenTotalSupply ). if the fixedEthDeposits its grater than the lidostEth balance the withdrawAmount its (lidoStEthbal \* fixedBearerTokensUser / fixedSharesTotalSupply) then it reduces fixedBearerTokens of user to 0 and fixedBearerToken bvalance and fixedSidesEthstartCapacit. then it creates a `fixedToVaultOngoingWithdrawalRequest` for msg sender for the withdrawamount, and pushes sender to `ongoingWithdrawalUSers` array

for variable side: it first check if the sender is the feeReceiver in that case it performs the feeReceiver withdraw. calculates amount owed to user, if that its greater than minimum appies protocl fee and request a lido withdraw for user. staking earnings are updated in internal mapping. in the case of fees accrued by vaul user gets its correspoding part based of his shares

If vault is ended: the vaultEndedWithdraw function its called. user of fixed rate gets its corresponding amount based og vaulEndedfixedDepositFunds / fixedBearerTokenSupply + fixedClaimTokenTotalSupply
for variable rate user gets its corresponfing staking sharesMoun + feeShareAmount

### claimFixedPremium()

when vault is started user can claim its fixed premium aka (fixedClaimTokenBal \* varaiableSideCapacity) / totalBalanceOfclaimTokensAtVaultStart. the the protocol mints `fixedBearerTokens` to user and burns the fixedClaimTokens, the fixedBearerTokens represent a portion of the fixed ETH side deposits at the end of the vault.

### finalizeVaultOngoingFixedWithdrawals()

when a fixed user calls withdraw on an ongoing vault it creates a requestId for that user and stores it in the fixedOngoingWithdrawalUSers array, this funcions filters that user from this array and then transfer the withdrawFunds.

### finalizeVaultOngoingVariableWithdrawals()

### finalizeVaultEndedWithdrawals

### feeReceiverFinalizeVaultOngoingVariableWithdrawals

only callable by fee receiver finalizes variableTovaultOngoingWithdrawals of selected user, doesn't call user addrress and updates variableToPendingWithdrawalAmount mapping of user

## IDEAS

DOS attack deposit making impossible to start a vault. see if it is possible
Check for DOS on for loops - have in mind that there's a min deposit of 0.01 eth
check invariant of at end state contract ETH balance should be zero.
can a user be front or back runned to make another user get a worse deal?
array errors when deleting, causing a requestid to be lost

a early mallicious user can backrun creation of vault and perform the minimum deposit and then frontrun the transactions where the vault its going to start causing dos. check taht specially for the variable side where early withdrawals have no cost for user also check for condition of remainingCapacity == 0 ||remaningCapacity >= minimunDepositAmount

try to drain or imbalance protocol

## Attack vectors

- no state check on some critical functions
- no mev protection on dex functionallity
- TODO perform POC to DOS withdrawal attack in for loop array to claim withdrawals.
  TODO POC of frontrun on vault initi

## SCOPE

LidoVault.sol
Vaultfactory
and interfaces

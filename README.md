# Cross-chain Rebase Token

1. A protocol that allows a user to deposit into a vault and in return, receive rebase tokens that represent their underlying balance
2. Rebase token -> balanceOf function is dynamic. This is needed to show the changing balance over time.
   - Balance increases linearly with time
   - Mint tokens to users every time they preform an action (mint, burn, transfer, bridge, etc...)
3. Interest rate
   - Individually set interest rate for each user based on some global interest rate for the protocol. This is set by taking a snapshot of the current interest rate at the time of a users deposit into the vault.
   - This individual interest rate is updated each time the user deposits into the vault.
   - The global interest rate can only be decreased to incentivize and reward early deposits. However, this also means depositing again at a later time could lower the individual interest rate of the user.
   - Early users would be best served by making subsequent deposits from different addresses to avoid updating to a lower interest rate.
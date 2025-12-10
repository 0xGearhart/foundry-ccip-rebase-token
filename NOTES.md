# Notes
TO-DO: 
1. add interactions script to cross chain tests for coverage
2. fix Makefile to reflect actual deployment flow
3. Deploy to sepolia and arb testnets
4. Fill out README outline and document deployment process

## Foundry CCIP Rebase Token

1. A protocol that allows a user to deposit into a vault and in return, receive rebase tokens that represent their underlying balance
2. Rebase token -> balanceOf function is dynamic. This is needed to show the changing balance over time.
   - Balance increases linearly with time
   - Mint tokens to users every time they preform an action (mint, burn, transfer, bridge, etc...)
3. Interest rate
   - Individually set interest rate for each user based on some global interest rate for the protocol. This is set by taking a snapshot of the current interest rate at the time of a users deposit into the vault.
   - This individual interest rate is updated each time the user deposits into the vault.
   - The global interest rate can only be decreased to incentivize and reward early deposits. However, this also means depositing again at a later time could lower the individual interest rate of the user.
   - Early users would be best served by making subsequent deposits from different addresses to avoid updating to a lower interest rate.


## Known Issues

1. totalSupply function from ERC20 will not include any accrued interest as looping through all users could result in denial of service as the array continues to grow with additional users.
2. Owner could grant anyone (including themselves) permission to mint and burn which would invalidate access control.
3. There can be precision loss if amount < 1 wei during interest calculations. This is due to truncation.
4. The decreasing interest rate system could be exploited in the following way: A user could make a small deposit early to lock in the highest interest rate. Then they could do a much larger deposit later from a new wallet (which would have a lower interest rate since the contract owner will be decreasing the global interest rate over time). If they then transfer the large secondary amount of Rebase Tokens to their first wallet with the higher interest rate, they would get to keep the higher interest rate on their entire balance. This is a known bug and is the result of trade offs between incentivising early deposits vs preventing someone from grieving other accounts by sending dust to their wallets to lower their interest rates. 
5. Users have the ability to increase their interest growth from linear to compounding by transferring on a consistent basis. This would prevent the users interest rate from decreasing over time since only deposit and redeem change the users interest rate. This would also constantly update the users principal balance to include the accrued interest which in essence allows the user to change their insert rate from linear (based off initial principal deposited), to compounding (where the user begins to accrue insert on their earned interest). The owner and deployer need to take steps to account for this possibility when calculating the amount of rewards needed in the vault contract. Failing to do so could result in denial of service due to insufficient ETH in the vault contract to pay out redemptions.

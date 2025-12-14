# CCIP-Rebase-Token

1. A protocol where users deposit into a vault and get rebase tokens in return that represent their balance.
2. Rebase token's balanceOf function is dynamic as balance increases with time. 
   - balance increases with time linearly
   - mint tokens to users everytime they mint, burn, transfer or bridge.
3. Interest rate
   - every user's deposit undergoes an interest rate which would be based on a global interest rate of the protocol. 
   - The global interest rate can only decrease to incentivise/ reward early adopters. 
   
4. Token pool for cross-chain liquidity 
   - We deploy a custom token pool for RBT because the interest rate has to be passed with tokens across the chain.
   - The custom token pool inherits from the token pool contract 
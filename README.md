# RWA Dynamic Fees (Uniswap v4 Hook)

A Foundry-based Solidity project that demonstrates **dynamic LP fee adjustment** for Uniswap v4 pools using **Chainlink Functions** to fetch volatility data from an external API. The hook reads the latest volatility signal and overrides the pool fee before swaps, increasing fees during volatile periods to better compensate liquidity providers.

## High-Level Overview

Uniswap v4 introduces hooks that can customize pool behavior at key lifecycle events. This project implements a hook that:

1. **Fetches volatility data** via Chainlink Functions.
2. **Calculates a dynamic fee** based on a base rate plus a volatility premium.
3. **Overrides pool fees** during `beforeSwap` using the v4 dynamic fee flag.

This creates an automated feedback loop between market conditions and liquidity fees, which can be useful for real-world asset (RWA) or other volatility-sensitive pools.

## Architecture & Flow

```
Chainlink Functions -> FunctionsConsumer -> DynamicFeeOverride -> Uniswap v4 Pool
```

- **FunctionsConsumer** issues an HTTP request to an external model API and stores the latest `price` and `volatility`.
- **DynamicFeeOverride** reads `volatility` from the consumer and returns an override fee during `beforeSwap`.
- **SwapHook** is a simple example hook used in tests to demonstrate hook lifecycle counts.

## Contracts

| Contract | Description |
| --- | --- |
| `src/FunctionsConsumer.sol` | Chainlink Functions client that fetches price & volatility. |
| `src/DynamicFeeOverride.sol` | Hook that calculates and returns dynamic LP fees. |
| `src/SwapHook.sol` | Minimal hook used in tests to track hook calls. |

### Dynamic Fee Model

- **Base Fee:** 0.10% (1000 bps)
- **Volatility Threshold:** 20% (scaled by 1000)
- **Volatility Factor:** 0.05% per 0.01 volatility above threshold
- **Fee Bounds:** 0.05% (min) to 1.00% (max)

## Repository Structure

```
├── src/                  # Hook contracts
├── script/               # Deployment and pool scripts
├── test/                 # Foundry tests
├── lib/                  # Submodules & dependencies
├── foundry.toml          # Foundry configuration
├── Makefile              # Build/test helpers
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (for dependency metadata in `package.json`)
- Chainlink Functions subscription + LINK (for live requests)

## Setup

```bash
# Initialize submodules (v4-core, v4-periphery, forge-std, etc.)
git submodule update --init --recursive

# Install Chainlink dependencies (see Makefile)
make install
```

## Build

```bash
# Using Makefile
make build

# Or directly
forge build
```

## Test

```bash
# Verbose test run
forge test -vvv
```

## Scripts (Local / Testnet)

The `script/` directory includes example flows for deploying and interacting with a v4 pool.

1. **Deploy the hook**
   ```bash
   forge script script/00_SwapHook.s.sol --rpc-url <RPC_URL> --broadcast
   ```
2. **Create a pool**
   ```bash
   forge script script/01_CreatePool.s.sol --rpc-url <RPC_URL> --broadcast
   ```
3. **Add liquidity**
   ```bash
   forge script script/02_AddLiquidity.s.sol --rpc-url <RPC_URL> --broadcast
   ```

> The scripts use hardcoded example Goerli addresses (now deprecated); update the `GOERLI_POOLMANAGER`, token addresses, and `HOOK_ADDRESS` constants in `script/00_SwapHook.s.sol`, `script/01_CreatePool.s.sol`, and `script/02_AddLiquidity.s.sol` for your target network (e.g., Sepolia). You can find current PoolManager and token addresses in the Uniswap v4 and Chainlink documentation for the network you target.

## Chainlink Functions Usage

1. Deploy `FunctionsConsumer` with the Chainlink router and DON ID.
2. Fund your subscription with LINK.
3. Call `sendRequest(subscriptionId, args)` to fetch the latest price + volatility.
4. `DynamicFeeOverride` will read the stored volatility and adjust fees on swap.

## Security Considerations

- The external API URL is hardcoded inside `FunctionsConsumer`, which makes the request target immutable, creates a single point of failure, and can expose you to unexpected or malicious data sources if the API is compromised. For production, consider passing the URL via constructor args or storing it in configurable storage with access controls.

## Notes & Limitations

- This repo is a proof-of-concept and is **not production audited**.

## License

MIT

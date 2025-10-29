# DFMM Framework 

DFMM is a modular framework for the Supra ecosystem, envisioned to include both the Dynamic Function Market Maker (DFMM) protocol and the Proof of Efficient Liquidity (PoEL) protocol—the former a novel cross-chain AMM and the latter a liquidity-bootstrapping layer. While DFMM will arrive next, the first live component is PoEL, a Move-based framework for cross- and inter-chain liquidity bootstrapping that creates yield-bearing Receipt tokens(iAssets) powered by SUPRA staking sourced from the PoEL vault, with the total borrowed SUPRA determined by the liquidity deposited. The protocol consists of two main modules, poel and iasset, plus several supporting contracts. The iasset module covers fuctions such as iAsset creation, minting, and redemption; collateralization-rate computation and reward accrual/claiming; and calculation of the SUPRA amount to be borrowed and delegated based on total liquidity deposited into IntraLayer vaults. The PoEL module covers functions such as delegation and unlock automation, staking-reward accounting and distribution, and validator-pool management (including replacements), as well as related admin and user operations. Additional components include the IntraLayer vaults where liquidity is deposited, a configuration module, and other supporting logic. 

## What’s here

- **Move modules (core protocol)**
  - `dfmm_framework::config` — roles, global params and settings, admin/owner/pool manager controls.
  - `dfmm_framework::iAsset` — iAsset creation/management, rewards indexation, nominal value calculation, premint/mint/redeem request/redeem flow.
  - `dfmm_framework::poel` — management of interaction with delegation pools, borrowable/borrowed accounting, reward allocation/distribution.
  - `dfmm_framework::asset_pool` — IntraLayer vault & pool registry: registers per-asset pools, handles the deposit and withdraw functionality. 
  - `dfmm_framework::evm_hypernova_adapter` — verifies EVM-side logs via Hypernova and triggers cross-chain borrow/premint.
  - (Plus helpers referenced by the core, e.g. `asset_util`, `asset_config`, `redeem_router`, etc.)

- **Solidity contracts (core protocol)**
  - Under `hypernova/eth-supra/eth_contracts/*` — EVM token-bridge components and Hypernova messaging pipeline used by the adapter, plus IntraLayer vault logic for asset deposits and related supporting logic

## Minimal repo layout (abridged)
Logical group of modules placed in the separate subdirectories. The same approach is applied for tests as well.

```
dfmm_framework/
│   ├── Move.toml
│   ├── deps/                          # local dependencies  (Move modules)
│   │   ├── hypernova_core             
│   │   ├── supra_oracle               
│   ├── sources/                       # Core Move modules
|   |   ├── config
│   │   |   ├── config.move                # Parameters, admin/owner controls
│   │   |   ├── asset_config.move          # Parameters for supara pools operations
|   |   ├── poel
│   │   |    ├── iAsset.move                # iAsset FA, rewards, pricing, accounting
│   │   |    ├── poel.move                  # Delegation, rewards allocation/distribution
│   │   |    ├── evm_hypernova_adapter.move # EVM bridge verification adapter
|   |   ├── asset_pool
│   │   |    ├── asset_pool.move            # Pools of supra-based assets
│   │   |    ├── asset_router.move          # Router for interacting with asset pools
|   |   ├── redeem
│   │   |    ├── redeem_router.move         # Router to execute redemption of iAssets into their underlying token
│   │   └── ...                        # other framework modules
│   └── tests/                         # Move tests
│   └── *.move                     # scenario/e2e tests
│
├── hypernova/eth-supra/eth_contracts/     # Solidity bridge + token-bridge service
│   ├── contracts/
│   │   ├── fee-operator/                  # Fees calculations
│   │   ├── hypernova-core/                # Hypernova protocol
│   │   ├── tokenBridge-service/           # Service layer (fees, message packing)
│   │   ├── token-vault/                   # Custody/vault contracts for bridged assets
│   │   └── interfaces/                    # Interfaces for contracts
│   └── test/                              # Solidity tests (Foundry/Hardhat)
│       └── *.t.sol | *.ts
└── README.md
```

> Exact file names/paths may differ slightly by branch, see the folders above.

## Prerequisites

- **Move toolchain**
  - [Supra CLI](https://docs.supra.com/network/move/getting-started/
  supra-cli-with-docker#install-and-setup-the-cli)
  - A supra account with testnet/mainnet funds for deployment.
  - Imported supra profile under the `Supra CLI`. [See details](https://docs.supra.com/network/move/getting-started/create-a-supra-account)
  - `move-analyzer` (optional, for IDEs)
- **Solidity toolchain** (optional, for EVM bridge)
  - [Foundry](https://book.getfoundry.sh/getting-started/installation)
  - Node.js and npm
  - An Ethereum wallet with testnet/mainnet funds for deployment

## Quick start (Move)

1. Install the Supra CLI and set a profile for your target network (localnet/testnet).
2. Check `Move.toml` for named addresses like `@access_control`, `@access_control`, `@supra_oracle`, `@dfmm_admin`  and set them as needed.
3. Build:
   ```bash
   supra move tool compile  --package-dir ${path_to_working_dir}
   ```
4. Unit tests (if enabled in modules):
   ```bash
   supra move tool tests  --package-dir ${path_to_working_dir}
   ```
5. Publish (adjust profile / network as appropriate):
   ```bash
   supra move tool publish  --package-dir ${path_to_working_dir}
   ```

## Quick start (Solidity)

1. Install dependencies:
```bash
forge install
```

2. Copy the `.env.example` to `.env` and fill in your configuration:
```bash
cp .env.example .env
```

3. To compile the contracts:
```bash
forge build
```

> The on-chain bridge contracts are ancillary; the Move adapter consumes Hypernova proofs emitted by these EVM contracts.

## License

This project is licensed under the **Business Source License 1.1 (BUSL-1.1)**.

- **Non-production use** (evaluation, research, education, security auditing) is permitted under BUSL-1.1.
- **Production use** (including offering as a service) requires a commercial license from Supra Labs **until the Change Date**.
- **Change Date:** 2028-01-01 — on or after this date, this version of the code will be available under **MIT**.
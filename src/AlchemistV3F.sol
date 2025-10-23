// SPDX-License-Identifier: MIT
pragma solidity =0.8.28 >=0.5.0 ^0.8.20 ^0.8.23 ^0.8.28 ^0.8.7;

// src/base/Errors.sol

/// @notice An error used to indicate that an action could not be completed because either the `msg.sender` or
///         `msg.origin` is not authorized.
error Unauthorized();

/// @notice An error used to indicate that an action could not be completed because the contract either already existed
///         or entered an illegal condition which is not recoverable from.
error IllegalState();

/// @notice An error used to indicate that an action could not be completed because of an illegal argument was passed
///         to the function.
error IllegalArgument();

/// @notice An error used to indicate that an action could not be completed because the required amount of allowance has not
///         been approved.
error InsufficientAllowance();

/// @notice An error used to indicate that the function input data is missing
error MissingInputData();

/// @notice An error used to indicate that the function input data is missing
error ZeroAmount();

/// @notice An error used to indicate that the function input data is missing
error ZeroAddress();

// src/interfaces/IAlchemistV3.sol

/// @notice Contract initialization parameters.
struct AlchemistInitializationParams {
    // The initial admin account.
    address admin;
    // The ERC20 token used to represent debt. i.e. the alAsset.
    address debtToken;
    // The ERC20 token used to represent the underlying token of the yield token.
    address underlyingToken;
    // The global maximum amount of deposited collateral.
    uint256 depositCap;
    // The minimum collateralization between 0 and 1 exclusive
    uint256 minimumCollateralization;
    // The global minimum collateralization, >= minimumCollateralization.
    uint256 globalMinimumCollateralization;
    // The minimum collateralization for liquidation eligibility. between 1 and minimumCollateralization inclusive.
    uint256 collateralizationLowerBound;
    // The initial transmuter or transmuter buffer.
    address transmuter;
    // The fee on user debt paid to the protocol.
    uint256 protocolFee;
    // The address that receives protocol fees.
    address protocolFeeReceiver;
    // Fee paid to liquidators.
    uint256 liquidatorFee;
    // Fee paid to liquidators forcing an account earmarked debt repayment.
    uint256 repaymentFee;
    // The address of the morpho v2 vault.
    address myt;
}

/// @notice A user account.
/// @notice This account struct is included in the main contract, AlchemistV3.sol, to aid readability.
struct Account {
    /// @notice User's collateral.
    uint256 collateralBalance;
    /// @notice User's debt.
    uint256 debt;
    /// @notice User debt earmarked for redemption.
    uint256 earmarked;
    /// @notice The amount of unlocked collateral.
    uint256 freeCollateral;
    /// @notice Last weight of earmark from most recent account sync.
    uint256 lastAccruedEarmarkWeight;
    /// @notice Last weight of redemption from most recent account sync.
    uint256 lastAccruedRedemptionWeight;
    /// @notice Last weight of collateral from most recent account sync.
    uint256 lastCollateralWeight;
    /// @notice Block of the most recent mint
    uint256 lastMintBlock;
    /// @notice The un-scaled locked collateral.
    uint256 rawLocked;
    /// @notice allowances for minting alAssets, per version.
    mapping(uint256 => mapping(address => uint256)) mintAllowances;
    /// @notice id used in the mintAllowances map which is incremented on reset.
    uint256 allowancesVersion;
    uint256 lastSurvivalAccumulator;
}

/// @notice Information associated with a redemption.
/// @notice This redemption struct is included in the main contract, AlchemistV3.sol, to aid in calculating user debt from historic redemptions.
struct RedemptionInfo {
    uint256 earmarked;
    uint256 debt;
    uint256 earmarkWeight;
}

interface IAlchemistV3Actions {
    /// @notice Approve `spender` to mint `amount` debt tokens.
    ///
    /// @param tokenId The tokenId of account granting approval.
    /// @param spender The address that will be approved to mint.
    /// @param amount  The amount of tokens that `spender` will be allowed to mint.

    function approveMint(uint256 tokenId, address spender, uint256 amount) external;

    /// @notice Synchronizes the state of the account owned by `owner`.
    ///
    /// @param tokenId   The tokenId of account
    function poke(uint256 tokenId) external;

    /// @notice Deposit a yield token into a user's account.
    /// @notice Create a new position by using zero (0) for the `recipientId`.
    /// @notice Users may create as many positions as they want.
    ///
    /// @notice An approval must be set for `yieldToken` which is greater than `amount`.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or the call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Deposit} event.
    ///
    /// @notice **_NOTE:_** When depositing, the `AlchemistV3` contract must have **allowance()** to spend funds on behalf of **msg.sender** for at least **amount** of the **yieldToken** being deposited.  This can be done via the standard `ERC20.approve()` method.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 amount = 50000;
    /// @notice IERC20(ydai).approve(alchemistAddress, amount);
    /// @notice AlchemistV3(alchemistAddress).deposit(amount, msg.sender);
    /// @notice ```
    ///
    /// @param amount     The amount of yield tokens to deposit.
    /// @param recipient  The owner of the account that will receive the resulting shares.
    /// @param recipientId The id of account.
    /// @return debtValue The value of deposited tokens normalized to debt token value.
    function deposit(uint256 amount, address recipient, uint256 recipientId) external returns (uint256 debtValue);

    /// @notice Withdraw `amount` yield tokens to `recipient`.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Withdraw} event.
    ///
    /// @notice **_NOTE:_** When withdrawing, th amount withdrawn must not put user over allowed LTV ratio.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice (uint256 LTV, ) = AlchemistV3(alchemistAddress).getLoanTerms(msg.sender);
    /// @notice (uint256 yieldTokens, ) = AlchemistV3(alchemistAddress).getCDP(tokenId);
    /// @notice uint256 maxWithdrawableTokens = (AlchemistV3(alchemistAddress).LTV() - LTV) * yieldTokens / LTV;
    /// @notice AlchemistV3(alchemistAddress).withdraw(maxWithdrawableTokens, msg.sender);
    /// @notice ```
    ///
    /// @param amount     The number of tokens to withdraw.
    /// @param recipient  The address of the recipient.
    /// @param tokenId The tokenId of account.
    ///
    /// @return amountWithdrawn The number of yield tokens that were withdrawn to `recipient`.
    function withdraw(uint256 amount, address recipient, uint256 tokenId) external returns (uint256 amountWithdrawn);

    /// @notice Mint `amount` debt tokens.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    ///
    /// @notice Emits a {Mint} event.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtDebt = 5000;
    /// @notice AlchemistV3(alchemistAddress).mint(amtDebt, msg.sender);
    /// @notice ```
    ///
    /// @param tokenId The tokenId of account.
    /// @param amount    The amount of tokens to mint.
    /// @param recipient The address of the recipient.
    function mint(uint256 tokenId, uint256 amount, address recipient) external;

    /// @notice Mint `amount` debt tokens from the account owned by `owner` to `recipient`.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    ///
    /// @notice Emits a {Mint} event.
    ///
    /// @notice **_NOTE:_** The caller of `mintFrom()` must have **mintAllowance()** to mint debt from the `Account` controlled by **owner** for at least the amount of **yieldTokens** that **shares** will be converted to.  This can be done via the `approveMint()` or `permitMint()` methods.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtDebt = 5000;
    /// @notice AlchemistV3(alchemistAddress).mintFrom(msg.sender, amtDebt, msg.sender);
    /// @notice ```
    ///
    /// @param tokenId   The tokenId of account.
    /// @param amount    The amount of tokens to mint.
    /// @param recipient The address of the recipient.
    function mintFrom(uint256 tokenId, uint256 amount, address recipient) external;

    /// @notice Burn `amount` debt tokens to credit the account owned by `recipientId`.
    ///
    /// @notice `amount` will be limited up to the amount of unearmarked debt that `recipient` currently holds.
    ///
    /// @notice `recipientId` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice account for `recipientId` must have non-zero debt or this call will revert with an {IllegalState} error.
    ///
    /// @notice Emits a {Burn} event.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtBurn = 5000;
    /// @notice AlchemistV3(alchemistAddress).burn(amtBurn, 420);
    /// @notice ```
    ///
    /// @param amount    The amount of tokens to burn.
    /// @param recipientId   The tokenId of account to being credited.
    ///
    /// @return amountBurned The amount of tokens that were burned.
    function burn(uint256 amount, uint256 recipientId) external returns (uint256 amountBurned);

    /// @notice Repay `amount` debt using yield tokens to credit the account owned by `recipientId`.
    ///
    /// @notice `amount` will be limited up to the amount of debt that `recipient` currently holds.
    ///
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Repay} event.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtRepay = 5000;
    /// @notice AlchemistV3(alchemistAddress).repay(amtRepay, msg.sender);
    /// @notice ```
    ///
    /// @param amount          The amount of the yield tokens to repay with.
    /// @param recipientTokenId   The tokenId of account to be repaid
    ///
    /// @return amountRepaid The amount of tokens that were repaid.
    function repay(uint256 amount, uint256 recipientTokenId) external returns (uint256 amountRepaid);

    /**
     * @notice Liquidates `owner` if the debt for account `owner` is greater than the underlying value of their collateral * LTV.
     *
     * @notice `owner` must be non-zero or this call will revert with an {IllegalArgument} error.
     *
     * @notice Emits a {Liquidate} event.
     *
     * @notice **Example:**
     * @notice ```
     * @notice AlchemistV2(alchemistAddress).liquidate(id4);
     * @notice ```
     *
     * @param accountId   The tokenId of account
     *
     * @return yieldAmount         Yield tokens sent to the transmuter.
     * @return feeInYield          Fee paid to liquidator in yield tokens.
     * @return feeInUnderlying     Fee paid to liquidator in underlying token.
     */
    function liquidate(uint256 accountId) external returns (uint256 yieldAmount, uint256 feeInYield, uint256 feeInUnderlying);

    /// @notice Liquidates `owners` if the debt for account `owner` is greater than the underlying value of their collateral * LTV.
    ///
    /// @notice `owner` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice AlchemistV3(alchemistAddress).batchLiquidate([id1, id35]);
    /// @notice ```
    ///
    /// @param accountIds   The tokenId of each account
    ///
    /// @return totalAmountLiquidated   Amount in yield tokens sent to the transmuter.
    /// @return totalFeesInYield        Amount sent to liquidator in yield tokens.
    /// @return totalFeesInUnderlying   Amount sent to liquidator in underlying token.
    function batchLiquidate(uint256[] memory accountIds)
        external
        returns (uint256 totalAmountLiquidated, uint256 totalFeesInYield, uint256 totalFeesInUnderlying);

    /// @notice Redeems `amount` debt from the alchemist in exchange for yield tokens sent to the transmuter.
    ///
    /// @notice This function is only callable by the transmuter.
    ///
    /// @notice Emits a {Redeem} event.
    ///
    /// @param amount The amount of tokens to redeem.
    function redeem(uint256 amount) external;

    /// @notice Reduces syntheticTokensIssued by `amount`.
    ///
    /// @notice This function is only callable by the transmuter.
    ///
    /// @param amount The amount of tokens burned during redemption.
    function reduceSyntheticsIssued(uint256 amount) external;

    /// @notice Sets lastTransmuterTokenBalance to `amount`.
    ///
    /// @notice This function is only callable by the transmuter.
    ///
    /// @param amount The balance of the transmuter.
    function setTransmuterTokenBalance(uint256 amount) external;

    /// @notice Resets all mint allowances by account managed by `tokenId`.
    ///
    /// @notice This function is only callable by the owner of the token id or the AlchemistV3Position contract.
    ///
    /// @notice Emits a {MintAllowancesReset} event.
    ///
    /// @param tokenId The token id of the account.
    function resetMintAllowances(uint256 tokenId) external;
}

interface IAlchemistV3AdminActions {
    /// @notice Sets the pending administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {PendingAdminUpdated} event.
    ///
    /// @dev This is the first step in the two-step process of setting a new administrator. After this function is called, the pending administrator will then need to call {acceptAdmin} to complete the process.
    ///
    /// @param value The address to set the pending admin to.
    function setPendingAdmin(address value) external;

    /// @notice Sets the active state of a guardian.
    ///
    /// @notice `msg.sender` must be the admin or this call will will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {GuardianSet} event.
    ///
    /// @param guardian The address of the target guardian.
    /// @param isActive The active state to set for the guardian.
    function setGuardian(address guardian, bool isActive) external;

    /// @notice Allows for `msg.sender` to accepts the role of administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice The current pending administrator must be non-zero or this call will revert with an {IllegalState} error.
    ///
    /// @dev This is the second step in the two-step process of setting a new administrator. After this function is successfully called, this pending administrator will be reset and the new administrator will be set.
    ///
    /// @notice Emits a {AdminUpdated} event.
    /// @notice Emits a {PendingAdminUpdated} event.
    function acceptAdmin() external;

    /// @notice Set a new alchemist deposit cap.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {DepositCapUpdated} event.
    ///
    /// @param value The value of the new deposit cap.
    function setDepositCap(uint256 value) external;

    /// @notice Sets the token adapter for the yield token.
    ///
    /// @notice `msg.sender` must be the admin or this call will will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {TokenAdapterSet} event.
    ///
    /// @param value The address of token adapter.
    function setTokenAdapter(address value) external;

    /// @notice Set the minimum collateralization ratio.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {MinimumCollateralizationUpdated} event.
    ///
    /// @param value The new minimum collateralization ratio.
    function setMinimumCollateralization(uint256 value) external;

    /// @notice Set a new protocol fee receiver.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {ProtocolFeeReceiverUpdated} event.
    ///
    /// @param receiver The address of the new fee receiver.
    function setProtocolFeeReceiver(address receiver) external;

    /// @notice Set a new protocol debt fee.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {ProtocolFeeUpdated} event.
    ///
    /// @param fee The new protocol debt fee.
    function setProtocolFee(uint256 fee) external;

    /// @notice Set a new liquidator fee.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {LiquidatorFeeUpdated} event.
    ///
    /// @param fee The new liquidator fee.
    function setLiquidatorFee(uint256 fee) external;

    /// @notice Set a new repayment fee.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {RepaymentFeeUpdated} event.
    ///
    /// @param fee The new repayment fee.
    function setRepaymentFee(uint256 fee) external;

    /// @notice Set the global minimum collateralization ratio.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {GlobalMinimumCollateralizationUpdated} event.
    ///
    /// @param value The new global minimum collateralization ratio.
    function setGlobalMinimumCollateralization(uint256 value) external;

    /// @notice Set the collateralization lower bound ratio.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {CollateralizationLowerBoundUpdated} event.
    ///
    /// @param value The new collateralization lower bound ratio.
    function setCollateralizationLowerBound(uint256 value) external;

    /// @notice Pause all future deposits in the Alchemist.
    ///
    /// @notice `msg.sender` must be the admin or guardian or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {DepositsPaused} event.
    ///
    /// @param isPaused The new pause state for deposits in the alchemist.
    function pauseDeposits(bool isPaused) external;

    /// @notice Pause all future loans in the Alchemist.
    ///
    /// @notice `msg.sender` must be the admin or guardian or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {LoansPaused} event.
    ///
    /// @param isPaused The new pause state for loans in the alchemist.
    function pauseLoans(bool isPaused) external;

    /// @notice Set the alchemist Fee vault.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {AlchemistFeeVaultUpdated} event.
    ///
    /// @param value The address of the new alchemist Fee vault.
    function setAlchemistFeeVault(address value) external;
}

interface IAlchemistV3Events {
    /// @notice Emitted when the pending admin is updated.
    ///
    /// @param pendingAdmin The address of the pending admin.
    event PendingAdminUpdated(address pendingAdmin);

    /// @notice Emitted when the alchemist Fee vault is updated.
    ///
    /// @param alchemistFeeVault The address of the alchemist Fee vault.
    event AlchemistFeeVaultUpdated(address alchemistFeeVault);

    /// @notice Emitted when the administrator is updated.
    ///
    /// @param admin The address of the administrator.
    event AdminUpdated(address admin);

    /// @notice Emitted when the deposit cap is updated.
    ///
    /// @param value The value of the new deposit cap.
    event DepositCapUpdated(uint256 value);

    /// @notice Emitted when a guardian is added or removed from the alchemist.
    ///
    /// @param guardian The addres of the new guardian.
    /// @param state    The active state of the guardian.
    event GuardianSet(address guardian, bool state);

    /// @notice Emitted when a new token adapter is set in the alchemist.
    ///
    /// @param adapter The addres of the new adapter.
    event TokenAdapterUpdated(address adapter);

    /// @notice Emitted when the transmuter is updated.
    ///
    /// @param transmuter The updated address of the transmuter.
    event TransmuterUpdated(address transmuter);

    /// @notice Emitted when the minimum collateralization is updated.
    ///
    /// @param minimumCollateralization The updated minimum collateralization.
    event MinimumCollateralizationUpdated(uint256 minimumCollateralization);

    /// @notice Emitted when the global minimum collateralization is updated.
    ///
    /// @param globalMinimumCollateralization The updated global minimum collateralization.
    event GlobalMinimumCollateralizationUpdated(uint256 globalMinimumCollateralization);

    /// @notice Emitted when the collateralization lower bound (for a liquidation) is updated.
    ///
    /// @param collateralizationLowerBound The updated collateralization lower bound.
    event CollateralizationLowerBoundUpdated(uint256 collateralizationLowerBound);

    /// @notice Emitted when deposits are paused or unpaused in the alchemist.
    ///
    /// @param isPaused The current pause state of deposits in the alchemist.
    event DepositsPaused(bool isPaused);

    /// @notice Emitted when loans are paused or unpaused in the alchemist.
    ///
    /// @param isPaused The current pause state of loans in the alchemist.
    event LoansPaused(bool isPaused);

    /// @notice Emitted when `owner` grants `spender` the ability to mint debt tokens on its behalf.
    ///
    /// @param ownerTokenId   The id of the account authorized to grant approval
    /// @param spender The address which is being permitted to mint tokens on the behalf of `owner`.
    /// @param amount  The amount of debt tokens that `spender` is allowed to mint.
    event ApproveMint(uint256 indexed ownerTokenId, address indexed spender, uint256 amount);

    /// @notice Emitted when a user deposits `amount of yieldToken to `recipient`.
    ///
    /// @notice This event does not imply that `sender` directly deposited yield tokens. It is possible that the
    ///         underlying tokens were wrapped.
    ///
    /// @param amount       The amount of yield tokens that were deposited.
    /// @param recipientId    The id of the account that received the deposited funds.
    event Deposit(uint256 amount, uint256 indexed recipientId);

    /// @notice Emitted when yieldToken is withdrawn from the account owned.
    ///         by `owner` to `recipient`.
    ///
    /// @notice This event does not imply that `recipient` received yield tokens. It is possible that the yield tokens
    ///         were unwrapped.
    ///
    /// @param amount     Amount of tokens withdrawn.
    /// @param tokenId The id of the account that the funds are withdrawn from.
    /// @param recipient  The address that received the withdrawn funds.
    event Withdraw(uint256 amount, uint256 indexed tokenId, address recipient);

    /// @notice Emitted when `amount` debt tokens are minted to `recipient` using the account owned by `owner`.
    ///
    /// @param tokenId     The tokenId of the account owner.
    /// @param amount    The amount of tokens that were minted.
    /// @param recipient The recipient of the minted tokens.
    event Mint(uint256 indexed tokenId, uint256 amount, address recipient);

    /// @notice Emitted when `sender` burns `amount` debt tokens to grant credit to  account owner `recipientId`.
    ///
    /// @param amount    The amount of tokens that were burned.
    /// @param recipientId The token id of account owned by recipientId that received credit for the burned tokens.
    event Burn(address indexed sender, uint256 amount, uint256 indexed recipientId);

    /// @notice Emitted when `amount` of `underlyingToken` are repaid to grant credit to account owned by `recipientId`.
    ///
    /// @param sender          The address which is repaying tokens.
    /// @param amount          The amount of the underlying token that was used to repay debt.
    /// @param recipientId     The id of account that received credit for the repaid tokens.
    /// @param credit          The amount of debt that was paid-off to the account owned by owner.
    event Repay(address indexed sender, uint256 amount, uint256 indexed recipientId, uint256 credit);

    /// @notice Emitted when the transmuter triggers a redemption.
    ///
    /// @param amount   The amount of debt to redeem.
    event Redemption(uint256 amount);

    /// @notice Emitted when the protocol debt fee is updated.
    ///
    /// @param fee  The new protocol fee.
    event ProtocolFeeUpdated(uint256 fee);

    /// @notice Emitted when the liquidator fee is updated.
    ///
    /// @param fee  The new liquidator fee.
    event LiquidatorFeeUpdated(uint256 fee);

    /// @notice Emitted when the repayment fee is updated.
    ///
    /// @param fee  The new repayment fee.
    event RepaymentFeeUpdated(uint256 fee);

    /// @notice Emitted when the fee receiver is updated.
    ///
    /// @param receiver   The address of the new receiver.
    event ProtocolFeeReceiverUpdated(address receiver);

    /// @notice Emitted when account owned by 'accountId' has been liquidated.
    ///
    /// @param accountId        The token id of the account liquidated
    /// @param liquidator   The address of the liquidator
    /// @param amount       The amount liquidated in yield tokens
    /// @param feeInYield          The liquidation fee sent to 'liquidator' in yield tokens.
    /// @param feeInUnderlying            The liquidation fee sent to 'liquidator' in ETH (if needed i.e. if there isn't enough remaining collateral to cover the fee).
    event Liquidated(uint256 indexed accountId, address liquidator, uint256 amount, uint256 feeInYield, uint256 feeInUnderlying);

    /// @notice Emitted when account for 'owner' has been liquidated.
    ///
    /// @param accounts       The address of the accounts liquidated
    /// @param liquidator   The address of the liquidator
    /// @param amount       The amount liquidated
    /// @param feeInYield          The liquidation fee sent to 'liquidator' in yield tokens.
    /// @param feeInETH            The liquidation fee sent to 'liquidator' in ETH (if needed i.e. if there isn't enough remaining collateral to cover the fee).
    event BatchLiquidated(uint256[] indexed accounts, address liquidator, uint256 amount, uint256 feeInYield, uint256 feeInETH);

    /// @notice Emitted when all mint allowances for account managed by `tokenId` are reset.
    ///
    /// @param tokenId       The tokenId of the account.
    event MintAllowancesReset(uint256 indexed tokenId);

    /// @notice Emitted when `amount` of debt is force repaid from `accountId`.
    ///
    /// @param accountId       The tokenId of the account.
    /// @param amount          The amount of debt repaid.
    /// @param creditToYield   The amount of collateral used to repay the debt in yield tokens.
    /// @param protocolFeeTotal The amount of protocol fee paid.
    event ForceRepay(uint256 indexed accountId, uint256 amount, uint256 creditToYield, uint256 protocolFeeTotal);

    /// @notice Emitted when `amount` of debt is repaid from `accountId`.
    ///
    /// @param accountId       The tokenId of the account.
    /// @param amount          The amount of debt repaid.
    /// @param feeReciever     The address of the fee receiver.
    /// @param fee             The amount of fee paid.
    event RepaymentFee(uint256 indexed accountId, uint256 amount, address feeReciever, uint256 fee);
}

interface IAlchemistV3Immutables {
    /// @notice Returns the version of the alchemist.
    ///
    /// @return The version.
    function version() external view returns (string memory);

    /// @notice Returns the address of the debt token used by the system.
    ///
    /// @return The address of the debt token.
    function debtToken() external view returns (address);
}

interface IAlchemistV3State {
    /// @notice Gets the address of the admin.
    ///
    /// @return admin The admin address.
    function admin() external view returns (address admin);

    function depositCap() external view returns (uint256 cap);

    function guardians(address guardian) external view returns (bool isActive);

    function cumulativeEarmarked() external view returns (uint256 earmarked);

    function lastEarmarkBlock() external view returns (uint256 block);

    function lastRedemptionBlock() external view returns (uint256 block);

    function lastTransmuterTokenBalance() external view returns (uint256 balance);

    function totalDebt() external view returns (uint256 debt);

    function totalSyntheticsIssued() external view returns (uint256 syntheticAmount);

    function protocolFee() external view returns (uint256 fee);

    function liquidatorFee() external view returns (uint256 fee);

    function repaymentFee() external view returns (uint256 fee);

    function underlyingConversionFactor() external view returns (uint256 factor);

    function protocolFeeReceiver() external view returns (address receiver);

    function underlyingToken() external view returns (address token);

    function myt() external view returns (address token);

    function depositsPaused() external view returns (bool isPaused);

    function loansPaused() external view returns (bool isPaused);

    function alchemistPositionNFT() external view returns (address nftContract);

    /// @notice Gets the address of the pending administrator.
    ///
    /// @return pendingAdmin The pending administrator address.
    function pendingAdmin() external view returns (address pendingAdmin);

    /// @notice Gets the address of the current yield token adapter.
    ///
    /// @return adapter The token adapter address.
    function tokenAdapter() external returns (address adapter);

    /// @notice Gets the address of the alchemist fee vault.
    ///
    /// @return vault The alchemist fee vault address.
    function alchemistFeeVault() external view returns (address vault);

    /// @notice Gets the address of the transmuter.
    ///
    /// @return transmuter The transmuter address.
    function transmuter() external view returns (address transmuter);

    /// @notice Gets the minimum collateralization.
    ///
    /// @notice Collateralization is determined by taking the total value of collateral that a user has deposited into their account and dividing it their debt.
    ///
    /// @dev The value returned is a 18 decimal fixed point integer.
    ///
    /// @return minimumCollateralization The minimum collateralization.
    function minimumCollateralization() external view returns (uint256 minimumCollateralization);

    /// @notice Gets the global minimum collateralization.
    ///
    /// @notice Collateralization is determined by taking the total value of collateral deposited in the alchemist and dividing it by the total debt.
    ///
    /// @dev The value returned is a 18 decimal fixed point integer.
    ///
    /// @return globalMinimumCollateralization The global minimum collateralization.
    function globalMinimumCollateralization() external view returns (uint256 globalMinimumCollateralization);

    ///  @notice Gets collaterlization level that will result in an account being eligible for partial liquidation
    function collateralizationLowerBound() external view returns (uint256 ratio);

    /// @dev Returns the debt value of `amount` yield tokens.
    ///
    /// @param amount   The amount to convert.
    function convertYieldTokensToDebt(uint256 amount) external view returns (uint256);

    /// @dev Returns the underlying value of `amount` yield tokens.
    ///
    /// @param amount   The amount to convert.
    function convertYieldTokensToUnderlying(uint256 amount) external view returns (uint256);

    /// @dev Returns the yield token value of `amount` debt tokens.
    ///
    /// @param amount   The amount to convert.
    function convertDebtTokensToYield(uint256 amount) external view returns (uint256);

    /// @dev Returns the yield token value of `amount` underlying tokens.
    ///
    /// @param amount   The amount to convert.
    function convertUnderlyingTokensToYield(uint256 amount) external view returns (uint256);

    /// @notice Calculates fee, net debt burn, and gross collateral seize,
    ///         using a single minCollateralization factor (FIXED_POINT_SCALAR scaled).
    /// @param collateral               Current collateral value
    /// @param debt                     Current debt value
    /// @param targetCollateralization  Target collateralization ratio, (e.g. 100/90 =  1.1111e18 for 111.11%)
    /// @param alchemistCurrentCollateralization Current collateralization ratio of the alchemist
    /// @param alchemistMinimumCollateralization Minimum collateralization ratio of the alchemist to trigger full liquidation
    /// @param feeBps                   Fee in basis points on the surplus (0–10000)
    /// @return grossCollateralToSeize  Total collateral to take (fee + net)
    /// @return debtToBurn              Amount of debt to erase (sent to protocol)
    /// @return fee                     Amount of collateral paid to liquidator
    /// @return outsourcedFee           Amount of fee paid to liquidator in underlying tokens in the event that account funds are insufficient to cover the fee
    function calculateLiquidation(
        uint256 collateral,
        uint256 debt,
        uint256 targetCollateralization,
        uint256 alchemistCurrentCollateralization,
        uint256 alchemistMinimumCollateralization,
        uint256 feeBps
    ) external view returns (uint256 grossCollateralToSeize, uint256 debtToBurn, uint256 fee, uint256 outsourcedFee);

    /// @dev Normalizes underlying tokens to debt tokens.
    /// @notice This is to handle decimal conversion in the case where underlying tokens have < 18 decimals.
    ///
    /// @param amount   The amount to convert.
    function normalizeUnderlyingTokensToDebt(uint256 amount) external view returns (uint256);

    /// @dev Normalizes debt tokens to underlying tokens.
    /// @notice This is to handle decimal conversion in the case where underlying tokens have < 18 decimals.
    ///
    /// @param amount   The amount to convert.
    function normalizeDebtTokensToUnderlying(uint256 amount) external view returns (uint256);

    /// @dev Get information about CDP of tokenId
    ///
    /// @param  tokenId   The token Id of the account.
    ///
    /// @return collateral  Collateral balance.
    /// @return debt        Current debt.
    /// @return earmarked   Current debt that is earmarked for redemption.
    function getCDP(uint256 tokenId) external view returns (uint256 collateral, uint256 debt, uint256 earmarked);

    /// @dev Gets total value of account managed by `tokenId` in units of underlying tokens.
    ///
    /// @param tokenId    tokenId of the account to query.
    ///
    /// @return value   Underlying value of the account.
    function totalValue(uint256 tokenId) external view returns (uint256 value);

    /// @dev Gets total value deposited in the alchemist
    ///
    /// @return amount   Total deposite amount.
    function getTotalDeposited() external view returns (uint256 amount);

    /// @dev Gets maximum debt that `user` can borrow from their CDP.
    ///
    /// @param tokenId    tokenId of the account to query.
    ///
    /// @return maxDebt   Maximum debt that can be taken.
    function getMaxBorrowable(uint256 tokenId) external view returns (uint256 maxDebt);

    /// @dev Gets total underlying value locked in the alchemist.
    ///
    /// @return TVL   Total value locked.
    function getTotalUnderlyingValue() external view returns (uint256 TVL);

    /// @notice Gets the amount of debt tokens `spender` is allowed to mint on behalf of `owner`.
    ///
    /// @param ownerTokenId    tokenId of the account to query.
    /// @param spender The address which is allowed to mint on behalf of `owner`.
    ///
    /// @return allowance The amount of debt tokens that `spender` can mint on behalf of `owner`.
    function mintAllowance(uint256 ownerTokenId, address spender) external view returns (uint256 allowance);
}

interface IAlchemistV3Errors {
    /// @notice An error which is used to indicate that an operation failed because an account became undercollateralized.
    error Undercollateralized();

    /// @notice An error which is used to indicate that a liquidate operation failed because an account is sufficiaenly collateralized.
    error LiquidationError();

    /// @notice An error which is used to indicate that a user is performing an action on an account that requires account ownership
    error UnauthorizedAccountAccessError();

    /// @notice An error which is used to indicate that a burn operation failed because the transmuter requires more debt in the system.
    ///
    /// @param amount    The amount of debt tokens that were requested to be burned.
    /// @param available The amount of debt tokens which can be burned;
    error BurnLimitExceeded(uint256 amount, uint256 available);

    /// @notice An error which is used to indicate that the account id used is not linked to any owner
    error UnknownAccountOwnerIDError();

    /// @notice An error which is used to indicate that the NFT address being set is the zero address
    error AlchemistV3NFTZeroAddressError();

    /// @notice An error which is used to indicate that the NFT address for the Alchemist has already been set
    error AlchemistV3NFTAlreadySetError();

    /// @notice An error which is used to indicate that the token address for the AlchemistTokenVault does not match the underlyingToken
    error AlchemistVaultTokenMismatchError();

    /// @notice An error which is used to indicate that a user is trying to repay on the same block they are minting
    error CannotRepayOnMintBlock();
}

/// @title  IAlchemistV3
/// @author Alchemix Finance
interface IAlchemistV3 is IAlchemistV3Actions, IAlchemistV3AdminActions, IAlchemistV3Errors, IAlchemistV3Immutables, IAlchemistV3Events, IAlchemistV3State {}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20_0 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/vault-v2/src/interfaces/IERC20.sol

// Copyright (c) 2025 Morpho Association

interface IERC20_1 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 shares) external returns (bool success);
    function transferFrom(address from, address to, uint256 shares) external returns (bool success);
    function approve(address spender, uint256 shares) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256);
}

// lib/vault-v2/src/interfaces/IERC2612.sol

// Copyright (c) 2025 Morpho Association

interface IERC2612 {
    function permit(address owner, address spender, uint256 shares, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// src/interfaces/IFeeVault.sol

/// @title  IFeeVault
/// @author Alchemix Finance
interface IFeeVault {
    /**
     * @notice Get the ERC20 token managed by this vault
     * @return The ERC20 token address
     */
    function token() external view returns (address);

    /**
     * @notice Get the total deposits in the vault
     * @return Total deposits
     */
    function totalDeposits() external view returns (uint256);

    /**
     * @notice Withdraw funds from the vault to a target address
     * @param recipient Address to receive the funds
     * @param amount Amount to withdraw
     */
    function withdraw(address recipient, uint256 amount) external;
}

// src/interfaces/ITokenAdapter.sol

/// @title  ITokenAdapter
/// @author Alchemix Finance
interface ITokenAdapter {
    /// @notice Gets the current version.
    ///
    /// @return The version.
    function version() external view returns (string memory);

    /// @notice Gets the address of the yield token that this adapter supports.
    ///
    /// @return The address of the yield token.
    function token() external view returns (address);

    /// @notice Gets the address of the underlying token that the yield token wraps.
    ///
    /// @return The address of the underlying token.
    function underlyingToken() external view returns (address);

    /// @notice Gets the number of underlying tokens that a single whole yield token is redeemable
    ///         for.
    ///
    /// @return The price.
    function price() external view returns (uint256);
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// src/libraries/PositionDecay.sol

/*
 * This file is based on code originally distributed under the BSD-4-Clause license.
 * Modifications made by <aphoticjezter@gmail.com>, 2025.
 *
 * Original notice:
 * ABDK Math 64.64 Smart Contract Library.  Copyright © 2019 by ABDK Consulting.
 * Author: Mikhail Vladimirov <mikhail.vladimirov@gmail.com>
 */

/* Fractional decay of Alchemist v3 positions via log2 weights in UQ136.120
 * fixed point representation.
 * User earmark/redemption can be represented as a product of fractions,
 * that approach zero as users are earmarked and redeemed.
 *
 * To deal with precision loss over time, we use the log(a*b)=log(a)+log(b)
 * identity to transform these fractions into summed logarithms.
 * Since these logarithms will be negative for all fractions in 0<x<1.0
 * we use the negated value of the logarithm for both exp and log, resulting
 * in monotonically non-decreasing weights for any non-zero earmark/redemption.
 */

library PositionDecay {
  /**
   * Result of Log2NegFrac(1)
   * Defined also as the largest input to Exp2NegFrac that produces a non-zero output
   */
  uint256 private constant LOG2NEGFRAC_1 = 0x80000000000000000000000000000000;

  /**
   * Calculate -log2((total-increment)/total)
   * Revert if total > uint128.max or increment > total
   *
   * @param increment (0 >= increment >= total)
   * @param total (0 >= total >= uint128.max)
   * @return UQ136.120 (0 > weightIncrement >= (128.0 + 2^-120))
   */
  function WeightIncrement(uint256 increment, uint256 total) internal pure returns (uint256) {
    unchecked {
      require(increment <= total);           //support ratios of 1.0 or less
      require(total <= type(uint128).max);   //Overflow check for (total - increment)<<128

      //By this check, and require(increment <= total <= uint128.max), we avoid div by zero
      if (increment == 0) {
        //log2(1.0) produces no weight increment
        return 0;
      }

      uint256 ratio = ((total - increment) << 128) / total;
      if (ratio == 0) {
        //return smallest weight increase where Exp2NegFrac returns zero
        return LOG2NEGFRAC_1+1;
      }
      return Log2NegFrac(ratio);
    }
  }

  /**
   * Calculate value-value*(2^-weightDelta)
   * Revert if value > uint128.max
   *
   * @param value (0 >= value >= uint128.max)
   * @param weightDelta (0 >= weightDelta)
   * @return (0 >= return >= value)
   */
  function ScaleByWeightDelta(uint256 value, uint256 weightDelta) internal pure returns (uint256) {
    unchecked {
      require(value <= type(uint128).max);   //Overflow check for value * Exp2NegFrac()
      
      if (weightDelta == 0) {
        //No decay has occurred
        return 0;
      }

      //This check is unnecessary given Exp2NegFrac repeats it
      //if (weightDelta > LOG2NEGFRAC_1) {
      //Full decay has occurred
      //  return value;
      //}

      return value - ((value * Exp2NegFrac(weightDelta)) >> 128);
    }
  }

  function SurvivalFromWeight(uint256 weight) internal pure returns (uint256) {
     unchecked {      
      // First weight will b 0 which needs to return 1
      // The Exp2NegFrac function cannot handle 0 this way so we hardcode the return
      if (weight == 0) {
        return uint256(1) << 128;
      }

      return Exp2NegFrac(weight);
     }
  }

  /**
   * Calculate negative log2 of x.  Revert if x == 0.
   *
   * @param x UQ128.128 (0 > x > 1.0)
   * @return UQ136.120 (0 > value >=128.0)
   */
  function Log2NegFrac(uint256 x) private pure returns (uint256) {
    unchecked {
      if (x >= 2**128) return 0;//Underflow

      require(x > 0);

      int256 msb = 0;
      uint256 xc = x;
      if (xc >= 0x10000000000000000) { xc >>= 64; msb += 64; }
      if (xc >= 0x100000000) { xc >>= 32; msb += 32; }
      if (xc >= 0x10000) { xc >>= 16; msb += 16; }
      if (xc >= 0x100) { xc >>= 8; msb += 8; }
      if (xc >= 0x10) { xc >>= 4; msb += 4; }
      if (xc >= 0x4) { xc >>= 2; msb += 2; }
      if (xc >= 0x2) msb += 1;  // No need to shift xc anymore

      int256 result = (msb - 128) << 120;
      uint256 ux = uint256(x) << uint256(127 - msb);
      for (int256 bit = 0x800000000000000000000000000000; bit > 0; bit >>= 1) {
        ux *= ux;
        uint256 b = ux >> 255;
        ux >>= 127 + b;
        result += bit * int256 (b);
      }
  
      return  uint256(-result);
    }
  }

  /**
   * Calculate 2^(-x).  Revert on overflow.
   *
   * @param x UQ136.120 negative exponent (0 > x)
   * @return UQ128.128 (0 > value > 1.0)
   */
  function Exp2NegFrac(uint256 x) private pure returns (uint256) {
    unchecked {
      if (x > LOG2NEGFRAC_1) return 0; // Underflow

      int256 nx = -int256(x);

      require (nx < 0); // Overflow

      // To account for precision loss resulting from the shifts
      // all constants below are increased for probabilistic compensation

      // Add 0x51 for rounding bias
      uint256 result = 0x80000000000000000000000000000051;

      // LSBs in constants are set for desired rounding bias
      if (nx & 2**119 > 0)
        result += result * 0xd413cccfe779921165f626cdd52afa89 >> 129;
      if (nx & 2**118 > 0)
        result += result * 0xc1bf828c6dc54b7a356918c17217b7bf >> 130;
      if (nx & 2**117 > 0)
        result += result * 0xb95c1e3ea8bd6e6fbe4628758a53c90f >> 131;
      if (nx & 2**116 > 0)
        result += result * 0xb5586cf9890f6298b92b71842a98364f >> 132;
      if (nx & 2**115 > 0)
        result += result * 0xb361a62b0ae875cf8a91d6d19482ffdf >> 133;
      if (nx & 2**114 > 0)
        result += result * 0x59347cef00c1dcdef95949ef4537bd3f >> 133;
      if (nx & 2**113 > 0)
        result += result * 0x2c7b53f6666adb094cd5c66db9bf481f >> 133;
      if (nx & 2**112 > 0)
        result += result * 0x1635f4b5797dac2535627d823b92a89f >> 133;
      if (nx & 2**111 > 0)
        result += result * 0xb190db43813d43fe33a5299e5ecf39f >> 133;
      if (nx & 2**110 > 0)
        result += result * 0x58c0bc5d19d8a0da437f9134474021f >> 133;
      if (nx & 2**109 > 0)
        result += result * 0x2c5e72080a3f425179538ab863cbc1f >> 133;
      if (nx & 2**108 > 0)
        result += result * 0x162ebdffb8ed7471c62ce395272e4df >> 133;
      if (nx & 2**107 > 0)
        result += result * 0xb17403f73f2dad959a9630122f87df >> 133;
      if (nx & 2**106 > 0)
        result += result * 0x58b986fb52923a130b86918d1cf67f >> 133;
      if (nx & 2**105 > 0)
        result += result * 0x2c5ca4bdc0a8ea88afab32a52404df >> 133;
      if (nx & 2**104 > 0)
        result += result * 0x162e4aaeeb8080c317e9495bd07f9f >> 133;
      if (nx & 2**103 > 0)
        result += result * 0xb17236b7935c5ddb03d36fa99f59f >> 133;
      if (nx & 2**102 > 0)
        result += result * 0x58b913abd8d949af9159802f6f93f >> 133;
      if (nx & 2**101 > 0)
        result += result * 0x2c5c87e9f0620c1c05b07353a2dbf >> 133;
      if (nx & 2**100 > 0)
        result += result * 0x162e4379f933b3f121d40d222ec7f >> 133;
      if (nx & 2**99 > 0)
        result += result * 0xb17219e3cdb2ff39429b7982c51f >> 133;
      if (nx & 2**98 > 0)
        result += result * 0x58b90c76e7e02c8d1ed758b9459f >> 133;
      if (nx & 2**97 > 0)
        result += result * 0x2c5c861cb431ec233c78045054bf >> 133;
      if (nx & 2**96 > 0)
        result += result * 0x162e4306aa2970dcdb2ddfa37fff >> 133;
      if (nx & 2**95 > 0)
        result += result * 0xb1721816918d7cbbf08d8b65e1f >> 133;
      if (nx & 2**94 > 0)
        result += result * 0x58b90c0398d73d284278e4e6f5f >> 133;
      if (nx & 2**93 > 0)
        result += result * 0x2c5c85ffe06fbe715456433e0df >> 133;
      if (nx & 2**92 > 0)
        result += result * 0x162e42ff7538e7354b033e89f3f >> 133;
      if (nx & 2**91 > 0)
        result += result * 0xb17217f9bdcb59a7839db9047f >> 133;
      if (nx & 2**90 > 0)
        result += result * 0x58b90bfc63e6b4d461b437ca1f >> 133;
      if (nx & 2**89 > 0)
        result += result * 0x2c5c85fe13339c6a8373fff9ff >> 133;
      if (nx & 2**88 > 0)
        result += result * 0x162e42ff01e9deb55bb48aaa9f >> 133;
      if (nx & 2**87 > 0)
        result += result * 0xb17217f7f08f37ab5036a35bf >> 133;
      if (nx & 2**86 > 0)
        result += result * 0x58b90bfbf097ac55c614e999f >> 133;
      if (nx & 2**85 > 0)
        result += result * 0x2c5c85fdf65fda4aeab37b55f >> 133;
      if (nx & 2**84 > 0)
        result += result * 0x162e42fefab4ee2d7749535ff >> 133;
      if (nx & 2**83 > 0)
        result += result * 0xb17217f7d3bb758bc21399ff >> 133;
      if (nx & 2**82 > 0)
        result += result * 0x58b90bfbe962bbcde2fd61bf >> 133;
      if (nx & 2**81 > 0)
        result += result * 0x2c5c85fdf4929e28f1fbc0bf >> 133;
      if (nx & 2**80 > 0)
        result += result * 0x162e42fefa419f24f91d299f >> 133;
      if (nx & 2**79 > 0)
        result += result * 0xb17217f7d1ee3969c9667df >> 133;
      if (nx & 2**78 > 0)
        result += result * 0x58b90bfbe8ef6cc564d28bf >> 133;
      if (nx & 2**77 > 0)
        result += result * 0x2c5c85fdf475ca66d27119f >> 133;
      if (nx & 2**76 > 0)
        result += result * 0x162e42fefa3a6a34713a81f >> 133;
      if (nx & 2**75 > 0)
        result += result * 0xb17217f7d1d165a7a9dbff >> 133;
      if (nx & 2**74 > 0)
        result += result * 0x58b90bfbe8e837d4dcefff >> 133;
      if (nx & 2**73 > 0)
        result += result * 0x2c5c85fdf473fd2ab0787f >> 133;
      if (nx & 2**72 > 0)
        result += result * 0x162e42fefa39f6e568bc5f >> 133;
      if (nx & 2**71 > 0)
        result += result * 0xb17217f7d1cf986b87e3f >> 133;
      if (nx & 2**70 > 0)
        result += result * 0x58b90bfbe8e7c485d471f >> 133;
      if (nx & 2**69 > 0)
        result += result * 0x2c5c85fdf473e056ee59f >> 133;
      if (nx & 2**68 > 0)
        result += result * 0x162e42fefa39efb07835f >> 133;
      if (nx & 2**67 > 0)
        result += result * 0xb17217f7d1cf7b97c5df >> 133;
      if (nx & 2**66 > 0)
        result += result * 0x58b90bfbe8e7bd50e3ff >> 133;
      if (nx & 2**65 > 0)
        result += result * 0x2c5c85fdf473de89b23f >> 133;
      if (nx & 2**64 > 0)
        result += result * 0x162e42fefa39ef3d293f >> 133;
      if (nx & 2**63 > 0)
        result += result * 0xb17217f7d1cf79ca89f >> 133;
      if (nx & 2**62 > 0)
        result += result * 0x58b90bfbe8e7bcdd95f >> 133;
      if (nx & 2**61 > 0)
        result += result * 0x2c5c85fdf473de6cdff >> 133;
      if (nx & 2**60 > 0)
        result += result * 0x162e42fefa39ef35f5f >> 133;
      if (nx & 2**59 > 0)
        result += result * 0xb17217f7d1cf79adbf >> 133;
      if (nx & 2**58 > 0)
        result += result * 0x58b90bfbe8e7bcd65f >> 133;
      if (nx & 2**57 > 0)
        result += result * 0x2c5c85fdf473de6b1f >> 133;
      if (nx & 2**56 > 0)
        result += result * 0x162e42fefa39ef359f >> 133;
      if (nx & 2**55 > 0)
        result += result * 0xb17217f7d1cf79abf >> 133;
      if (nx & 2**54 > 0)
        result += result * 0x58b90bfbe8e7bcd5f >> 133;
      if (nx & 2**53 > 0)
        result += result * 0x2c5c85fdf473de6bf >> 133;
      if (nx & 2**52 > 0)
        result += result * 0x162e42fefa39ef35f >> 133;
      if (nx & 2**51 > 0)
        result += result * 0xb17217f7d1cf79bf >> 133;
      if (nx & 2**50 > 0)
        result += result * 0x58b90bfbe8e7bcdf >> 133;
      if (nx & 2**49 > 0)
        result += result * 0x2c5c85fdf473de7f >> 133;
      if (nx & 2**48 > 0)
        result += result * 0x162e42fefa39ef3f >> 133;
      if (nx & 2**47 > 0)
        result += result * 0xb17217f7d1cf79f >> 133;
      if (nx & 2**46 > 0)
        result += result * 0x58b90bfbe8e7bdf >> 133;
      if (nx & 2**45 > 0)
        result += result * 0x2c5c85fdf473dff >> 133;
      if (nx & 2**44 > 0)
        result += result * 0x162e42fefa39eff >> 133;
      if (nx & 2**43 > 0)
        result += result * 0xb17217f7d1cf7f >> 133;
      if (nx & 2**42 > 0)
        result += result * 0x58b90bfbe8e7bf >> 133;
      if (nx & 2**41 > 0)
        result += result * 0x2c5c85fdf473df >> 133;
      if (nx & 2**40 > 0)
        result += result * 0x162e42fefa39ff >> 133;
      if (nx & 2**39 > 0)
        result += result * 0xb17217f7d1cff >> 133;
      if (nx & 2**38 > 0)
        result += result * 0x58b90bfbe8e7f >> 133;
      if (nx & 2**37 > 0)
        result += result * 0x2c5c85fdf473f >> 133;
      if (nx & 2**36 > 0)
        result += result * 0x162e42fefa39f >> 133;
      if (nx & 2**35 > 0)
        result += result * 0xb17217f7d1df >> 133;
      if (nx & 2**34 > 0)
        result += result * 0x58b90bfbe8ff >> 133;
      if (nx & 2**33 > 0)
        result += result * 0x2c5c85fdf47f >> 133;
      if (nx & 2**32 > 0)
        result += result * 0x162e42fefa3f >> 133;
      if (nx & 2**31 > 0)
        result += result * 0xb17217f7d1f >> 133;
      if (nx & 2**30 > 0)
        result += result * 0x58b90bfbe9f >> 133;
      if (nx & 2**29 > 0)
        result += result * 0x2c5c85fdf5f >> 133;
      if (nx & 2**28 > 0)
        result += result * 0x162e42fefbf >> 133;
      if (nx & 2**27 > 0)
        result += result * 0xb17217f7df >> 133;
      if (nx & 2**26 > 0)
        result += result * 0x58b90bfbff >> 133;
      if (nx & 2**25 > 0)
        result += result * 0x2c5c85fdff >> 133;
      if (nx & 2**24 > 0)
        result += result * 0x162e42feff >> 133;
      if (nx & 2**23 > 0)
        result += result * 0xb17217f7f >> 133;
      if (nx & 2**22 > 0)
        result += result * 0x58b90bfbf >> 133;
      if (nx & 2**21 > 0)
        result += result * 0x2c5c85fdf >> 133;
      if (nx & 2**20 > 0)
        result += result * 0x162e42fff >> 133;
      if (nx & 2**19 > 0)
        result += result * 0xb17217ff >> 133;
      if (nx & 2**18 > 0)
        result += result * 0x58b90bff >> 133;
      if (nx & 2**17 > 0)
        result += result * 0x2c5c85ff >> 133;
      if (nx & 2**16 > 0)
        result += result * 0x162e42ff >> 133;
      if (nx & 2**15 > 0)
        result += result * 0xb17217f >> 133;
      if (nx & 2**14 > 0)
        result += result * 0x58b90bf >> 133;
      if (nx & 2**13 > 0)
        result += result * 0x2c5c85f >> 133;
      if (nx & 2**12 > 0)
        result += result * 0x162e43f >> 133;
      if (nx & 2**11 > 0)
        result += result * 0xb1721f >> 133;
      if (nx & 2**10 > 0)
        result += result * 0x58b91f >> 133;
      if (nx & 2**9 > 0)
        result += result * 0x2c5c9f >> 133;
      if (nx & 2**8 > 0)
        result += result * 0x162e5f >> 133;
      if (nx & 2**7 > 0)
        result += result * 0xb173f >> 133;
      if (nx & 2**6 > 0)
        result += result * 0x58b9f >> 133;
      if (nx & 2**5 > 0)
        result += result * 0x2c5df >> 133;
      if (nx & 2**4 > 0)
        result += result * 0x162ff >> 133;
      if (nx & 2**3 > 0)
        result += result * 0xb17f >> 133;
      if (nx & 2**2 > 0)
        result += result * 0x58bf >> 133;
      if (nx & 2**1 > 0)
        result += result * 0x2c5f >> 133;
      if (nx & 2**0 > 0)
        result += result * 0x163f >> 133;

      //(nx >> 120) is always <= -1 due to SAR and require(nx<0)
      result >>= uint256 (int256 (-1 - (nx >> 120)));
      require (result <= uint256 (type(uint128).max));

      return result;
    }
  }
}

// src/interfaces/IAlchemistTokenVault.sol

/**
 * @title IAlchemistTokenVault
 * @notice Interface for the AlchemistTokenVault contract
 */
interface IAlchemistTokenVault {
    /**
     * @notice Get the ERC20 token managed by this vault
     * @return The ERC20 token address
     */
    function token() external view returns (address);

    /**
     * @notice Get the address of the Alchemist contract
     * @return The Alchemist contract address
     */
    function alchemist() external view returns (address);

    /**
     * @notice Check if an address is authorized to withdraw
     * @param withdrawer The address to check
     * @return Whether the address is authorized
     */
    function authorizedWithdrawers(address withdrawer) external view returns (bool);

    /**
     * @notice Allows anyone to deposit tokens into the vault
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Allows only the Alchemist or authorized withdrawers to withdraw tokens
     * @param to The address to receive the tokens
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(address to, uint256 amount) external;

    /**
     * @notice Sets the authorized status of a withdrawer
     * @param withdrawer The address to authorize/deauthorize
     * @param status True to authorize, false to deauthorize
     */
    function setAuthorizedWithdrawer(address withdrawer, bool status) external;

    /**
     * @notice Updates the Alchemist address
     * @param _alchemist The new Alchemist address
     */
    function setAlchemist(address _alchemist) external;

    /**
     * @notice Emitted when tokens are deposited
     */
    event Deposited(address indexed from, uint256 amount);

    /**
     * @notice Emitted when tokens are withdrawn
     */
    event Withdrawn(address indexed to, uint256 amount);

    /**
     * @notice Emitted when an authorized withdrawer status changes
     */
    event AuthorizedWithdrawerSet(address indexed withdrawer, bool status);

    /**
     * @notice Emitted when the Alchemist address is updated
     */
    event AlchemistUpdated(address indexed newAlchemist);
}

// src/interfaces/IERC20Burnable.sol

/// @title  IERC20Burnable
/// @author Alchemix Finance
interface IERC20Burnable is IERC20_0 {
    /// @notice Burns `amount` tokens from the balance of `msg.sender`.
    ///
    /// @param amount The amount of tokens to burn.
    ///
    /// @return If burning the tokens was successful.
    function burn(uint256 amount) external returns (bool);

    /// @notice Burns `amount` tokens from `owner`'s balance.
    ///
    /// @param owner  The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    ///
    /// @return If burning the tokens was successful.
    function burnFrom(address owner, uint256 amount) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20_0 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// src/interfaces/IERC20Mintable.sol

/// @title  IERC20Mintable
/// @author Alchemix Finance
interface IERC20Mintable is IERC20_0 {
    /// @notice Mints `amount` tokens to `recipient`.
    ///
    /// @param recipient The address which will receive the minted tokens.
    /// @param amount    The amount of tokens to mint.
    function mint(address recipient, uint256 amount) external;
}

// lib/vault-v2/src/interfaces/IERC4626.sol

// Copyright (c) 2025 Morpho Association

interface IERC4626 is IERC20_1 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address onBehalf) external returns (uint256 shares);
    function mint(uint256 shares, address onBehalf) external returns (uint256 assets);
    function withdraw(uint256 assets, address onBehalf, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address onBehalf, address receiver) external returns (uint256 assets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function maxDeposit(address onBehalf) external view returns (uint256 assets);
    function maxMint(address onBehalf) external view returns (uint256 shares);
    function maxWithdraw(address onBehalf) external view returns (uint256 assets);
    function maxRedeem(address onBehalf) external view returns (uint256 shares);
}

// lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC-721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// src/interfaces/ITransmuter.sol

interface ITransmuter {
    struct StakingPosition {
        // Amount staked.
        uint256 amount;
        // Block when the position was opened
        uint256 startBlock;
        // Time when the transmutation will be complete/claimable.
        uint256 maturationBlock;
    }

    struct TransmuterInitializationParams {
        address syntheticToken;
        address feeReceiver;
        uint256 timeToTransmute;
        uint256 transmutationFee;
        uint256 exitFee;
        uint256 graphSize;
    }

    /// @notice Gets the address of the alchemist.
    ///
    /// @return alchemist The alchemist address.
    function alchemist() external view returns (IAlchemistV3 alchemist);

    /// @notice Gets the address of the admin.
    ///
    /// @return admin The admin address.
    function admin() external view returns (address admin);

    /// @notice Gets the address of the pending admin.
    ///
    /// @return pendingAdmin The pending admin address.
    function pendingAdmin() external view returns (address pendingAdmin);

    /// @notice Returns the version of the alchemist.
    function version() external view returns (string memory version);

    /// @notice Returns the address of the synthetic token.
    function syntheticToken() external view returns (address token);

    /// @notice Returns the current transmuter deposit cap.
    function depositCap() external view returns (uint256 cap);

    /// @notice Returns the transmutation early exit fee.
    /// @notice This is for users who choose to pull from the transmuter before their position has fully matured.
    function exitFee() external view returns (uint256 fee);

    /// @notice Returns the transmutation fee.
    /// @notice This fee affects all claims.
    function transmutationFee() external view returns (uint256 fee);

    /// @notice Returns the current time to transmute (in blocks).
    function timeToTransmute() external view returns (uint256 transmutationTime);

    /// @notice Returns the total locked debt tokens in the transmuter.
    function totalLocked() external view returns (uint256 totalLocked);

    function protocolFeeReceiver() external view returns (address receiver);

    /// @notice Sets the pending administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {PendingAdminUpdated} event.
    ///
    /// @dev This is the first step in the two-step process of setting a new administrator. After this function is called, the pending administrator will then need to call {acceptAdmin} to complete the process.
    ///
    /// @param value The address to set the pending admin to.
    function setPendingAdmin(address value) external;

    /// @notice Allows for `msg.sender` to accepts the role of administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice The current pending administrator must be non-zero or this call will revert with an {IllegalState} error.
    ///
    /// @dev This is the second step in the two-step process of setting a new administrator. After this function is successfully called, this pending administrator will be reset and the new administrator will be set.
    ///
    /// @notice Emits a {AdminUpdated} event.
    /// @notice Emits a {PendingAdminUpdated} event.
    function acceptAdmin() external;

    /// @notice Set a new alchemist for redemptions.
    ///
    /// @param alchemist The address of the new alchemist.
    function setAlchemist(address alchemist) external;

    /// @notice Updates transmuter deposit limit to `cap`.
    ///
    /// @notice `cap` must be greater or equal to current synths locked in the transmuter.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    ///
    /// @param cap    The new deposit cap.
    function setDepositCap(uint256 cap) external;

    /// @notice Sets time to transmute to `time`.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param time    The new transmutation time.
    function setTransmutationTime(uint256 time) external;

    /// @notice Sets the transmutation fee to `fee`.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param fee    The new transmutation fee.
    function setTransmutationFee(uint256 fee) external;

    /// @notice Sets the early exit fee to `fee`.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param fee    The new exit fee.
    function setExitFee(uint256 fee) external;

    /// @notice Set a new protocol fee receiver.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {ProtocolFeeReceiverUpdated} event.
    ///
    /// @param receiver The address of the new fee receiver.
    function setProtocolFeeReceiver(address receiver) external;

    /// @notice Gets position info for `id`.
    ///
    /// @param id      NFT ID,
    ///
    /// @return position   Position data.
    function getPosition(uint256 id) external view returns (StakingPosition memory position);

    /// @notice Creates a new staking position in the transmuter.
    ///
    /// @notice `depositAmount` must be non-zero or this call will revert with a {DepositZeroAmount} error.
    ///
    /// @notice Emits a {PositionCreated} event.
    ///
    /// @param depositAmount    Amount of debt tokens to deposit.
    function createRedemption(uint256 depositAmount) external;

    /// @notice Claims a staking position from the transmuter.
    ///
    /// @notice `id` must return a valid position or this call will revert with a {PositionNotFound} error.
    /// @notice End block of position must be <= to current block or this call will revert with a {PrematureClaim} error.
    ///
    /// @notice Emits a {PositionClaimed} event.
    ///
    /// @param id   Id of the nft representing the position.
    function claimRedemption(uint256 id) external;

    /// @notice Queries the staking graph from `startBlock` to `endBlock`.
    ///
    /// @param startBlock   The block to start query from.
    /// @param endBlock     The last block to query up to.
    ///
    /// @return totalValue  Total value of tokens needed to fulfill redemptions between `startBlock` and `endBlock`.
    function queryGraph(uint256 startBlock, uint256 endBlock) external view returns (uint256 totalValue);

    /// @notice Emitted when the admin address is updated.
    ///
    /// @param admin The new admin address.
    event AdminUpdated(address admin);

    /// @notice Emitted when the pending admin is updated.
    ///
    /// @param pendingAdmin The address of the pending admin.
    event PendingAdminUpdated(address pendingAdmin);

    /// @notice Emitted when the associated alchemist is updated.
    ///
    /// @param alchemist The address of the new alchemist.
    event AlchemistUpdated(address alchemist);

    /// @dev Emitted when a position is created.
    ///
    /// @param creator          The address that created the position.
    /// @param amountStaked     The amount of tokens staked.
    /// @param nftId            The id of the newly minted NFT.
    event PositionCreated(address indexed creator, uint256 amountStaked, uint256 nftId);

    /// @dev Emitted when a position is claimed.
    ///
    /// @param claimer          The address that claimed the position.
    /// @param amountClaimed    The amount of tokens claimed.
    /// @param amountUnclaimed  The amount of tokens that were not transmuted.
    event PositionClaimed(address indexed claimer, uint256 amountClaimed, uint256 amountUnclaimed);

    /// @dev Emitted when the graph size is extended.
    ///
    /// @param size  The new length of the graph.
    event GraphSizeUpdated(uint256 size);

    /// @dev Emitted when the deposit cap is updated.
    ///
    /// @param cap  The new transmuter deposit cap.
    event DepositCapUpdated(uint256 cap);

    /// @dev Emitted when the transmutaiton time is updated.
    ///
    /// @param time  The new transmutation time in blocks.
    event TransmutationTimeUpdated(uint256 time);

    /// @dev Emitted when the transmutaiton fee is updated.
    ///
    /// @param fee  The new transmutation fee.
    event TransmutationFeeUpdated(uint256 fee);

    /// @dev Emitted when the early exit fee is updated.
    ///
    /// @param fee  The new exit fee.
    event ExitFeeUpdated(uint256 fee);

    /// @dev Emitted when the fee receiver is updates.
    ///
    /// @param recevier  The new receiver.
    event ProtocolFeeReceiverUpdated(address recevier);
}

// src/libraries/SafeCast.sol

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        if (y >= 2 ** 255) {
            revert IllegalArgument();
        }
        z = int256(y);
    }

    /// @notice Cast a int256 to a uint256, revert on underflow
    /// @param y The int256 to be casted
    /// @return z The casted integer, now type uint256
    function toUint256(int256 y) internal pure returns (uint256 z) {
        if (y < 0) {
            revert IllegalArgument();
        }
        z = uint256(y);
    }

    /// @notice Cast a uint256 to a uint128, revert on underflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type uint128
    function uint256ToUint128(uint256 y) internal pure returns (uint128 z) {
        if (y > type(uint128).max) {
            revert IllegalArgument();
        }
        z = uint128(y);
    }

    /// @notice Cast a uint128 to a uint256
    /// @param y The uint128 to be casted
    /// @return z The casted integer, now type uint256
    function uint128ToUint256(uint128 y) internal pure returns (uint256 z) {
        // Upcast will not overflow
        z = uint256(y);
    }
}

// src/interfaces/IERC721Enumerable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Enumerable.sol)

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// src/interfaces/IAlchemistV3Position.sol

/**
 * @title IAlchemistV3Position
 * @notice Interface for the AlchemistV3Position ERC721 token.
 */
interface IAlchemistV3Position is IERC721Enumerable {
    /**
     * @notice Mints a new position NFT to the specified address.
     * @param to The recipient address for the new position.
     * @return tokenId The unique token ID minted.
     */
    function mint(address to) external returns (uint256);

    /**
     * @notice Burns the NFT with the specified token ID.
     * @param tokenId The ID of the token to burn.
     */
    function burn(uint256 tokenId) external;

    /**
     * @notice Returns the address of the AlchemistV3 contract which is allowed to mint and burn tokens.
     */
    function alchemist() external view returns (address);

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// lib/vault-v2/src/interfaces/IVaultV2.sol

// Copyright (c) 2025 Morpho Association

struct Caps {
    uint256 allocation;
    uint128 absoluteCap;
    uint128 relativeCap;
}

interface IVaultV2 is IERC4626, IERC2612 {
    // State variables
    function virtualShares() external view returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function receiveSharesGate() external view returns (address);
    function sendSharesGate() external view returns (address);
    function receiveAssetsGate() external view returns (address);
    function sendAssetsGate() external view returns (address);
    function adapterRegistry() external view returns (address);
    function isSentinel(address account) external view returns (bool);
    function isAllocator(address account) external view returns (bool);
    function firstTotalAssets() external view returns (uint256);
    function _totalAssets() external view returns (uint128);
    function lastUpdate() external view returns (uint64);
    function maxRate() external view returns (uint64);
    function adapters(uint256 index) external view returns (address);
    function adaptersLength() external view returns (uint256);
    function isAdapter(address account) external view returns (bool);
    function allocation(bytes32 id) external view returns (uint256);
    function absoluteCap(bytes32 id) external view returns (uint256);
    function relativeCap(bytes32 id) external view returns (uint256);
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
    function timelock(bytes4 selector) external view returns (uint256);
    function abdicated(bytes4 selector) external view returns (bool);
    function executableAt(bytes memory data) external view returns (uint256);
    function performanceFee() external view returns (uint96);
    function performanceFeeRecipient() external view returns (address);
    function managementFee() external view returns (uint96);
    function managementFeeRecipient() external view returns (address);

    // Gating
    function canSendShares(address account) external view returns (bool);
    function canReceiveShares(address account) external view returns (bool);
    function canSendAssets(address account) external view returns (bool);
    function canReceiveAssets(address account) external view returns (bool);

    // Multicall
    function multicall(bytes[] memory data) external;

    // Owner functions
    function setOwner(address newOwner) external;
    function setCurator(address newCurator) external;
    function setIsSentinel(address account, bool isSentinel) external;
    function setName(string memory newName) external;
    function setSymbol(string memory newSymbol) external;

    // Timelocks for curator functions
    function submit(bytes memory data) external;
    function revoke(bytes memory data) external;

    // Curator functions
    function setIsAllocator(address account, bool newIsAllocator) external;
    function setReceiveSharesGate(address newReceiveSharesGate) external;
    function setSendSharesGate(address newSendSharesGate) external;
    function setReceiveAssetsGate(address newReceiveAssetsGate) external;
    function setSendAssetsGate(address newSendAssetsGate) external;
    function setAdapterRegistry(address newAdapterRegistry) external;
    function addAdapter(address account) external;
    function removeAdapter(address account) external;
    function increaseTimelock(bytes4 selector, uint256 newDuration) external;
    function decreaseTimelock(bytes4 selector, uint256 newDuration) external;
    function abdicate(bytes4 selector) external;
    function setPerformanceFee(uint256 newPerformanceFee) external;
    function setManagementFee(uint256 newManagementFee) external;
    function setPerformanceFeeRecipient(address newPerformanceFeeRecipient) external;
    function setManagementFeeRecipient(address newManagementFeeRecipient) external;
    function increaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function decreaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function increaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function decreaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function setMaxRate(uint256 newMaxRate) external;
    function setForceDeallocatePenalty(address adapter, uint256 newForceDeallocatePenalty) external;

    // Allocator functions
    function allocate(address adapter, bytes memory data, uint256 assets) external;
    function deallocate(address adapter, bytes memory data, uint256 assets) external;
    function setLiquidityAdapterAndData(address newLiquidityAdapter, bytes memory newLiquidityData) external;

    // Exchange rate
    function accrueInterest() external;
    function accrueInterestView()
        external
        view
        returns (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares);

    // Force deallocate
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256 penaltyShares);
}

// src/libraries/TokenUtils.sol

/// @title  TokenUtils
/// @author Alchemix Finance
library TokenUtils {
    /// @notice An error used to indicate that a call to an ERC20 contract failed.
    ///
    /// @param target  The target address.
    /// @param success If the call to the token was a success.
    /// @param data    The resulting data from the call. This is error data when the call was not a success. Otherwise,
    ///                this is malformed data when the call was a success.
    error ERC20CallFailed(address target, bool success, bytes data);

    /// @dev A safe function to get the decimals of an ERC20 token.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the query fails or returns an unexpected value.
    ///
    /// @param token The target token.
    ///
    /// @return The amount of decimals of the token.
    function expectDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));

        if (token.code.length == 0 || !success || data.length < 32) {
            revert ERC20CallFailed(token, success, data);
        }

        return abi.decode(data, (uint8));
    }

    /// @dev Gets the balance of tokens held by an account.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the query fails or returns an unexpected value.
    ///
    /// @param token   The token to check the balance of.
    /// @param account The address of the token holder.
    ///
    /// @return The balance of the tokens held by an account.
    function safeBalanceOf(address token, address account) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(IERC20_0.balanceOf.selector, account));

        if (token.code.length == 0 || !success || data.length < 32) {
            revert ERC20CallFailed(token, success, data);
        }

        return abi.decode(data, (uint256));
    }

    /// @dev Transfers tokens to another address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the transfer failed or returns an unexpected value.
    ///
    /// @param token     The token to transfer.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to transfer.
    function safeTransfer(address token, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20_0.transfer.selector, recipient, amount));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Approves tokens for the smart contract.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the approval fails or returns an unexpected value.
    ///
    /// @param token   The token to approve.
    /// @param spender The contract to spend the tokens.
    /// @param value   The amount of tokens to approve.
    function safeApprove(address token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20_0.approve.selector, spender, value));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Transfer tokens from one address to another address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the transfer fails or returns an unexpected value.
    ///
    /// @param token     The token to transfer.
    /// @param owner     The address of the owner.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to transfer.
    function safeTransferFrom(address token, address owner, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20_0.transferFrom.selector, owner, recipient, amount));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Mints tokens to an address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the mint fails or returns an unexpected value.
    ///
    /// @param token     The token to mint.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to mint.
    function safeMint(address token, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Mintable.mint.selector, recipient, amount));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Burns tokens.
    ///
    /// Reverts with a `CallFailed` error if execution of the burn fails or returns an unexpected value.
    ///
    /// @param token  The token to burn.
    /// @param amount The amount of tokens to burn.
    function safeBurn(address token, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Burnable.burn.selector, amount));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Burns tokens from its total supply.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the burn fails or returns an unexpected value.
    ///
    /// @param token  The token to burn.
    /// @param owner  The owner of the tokens.
    /// @param amount The amount of tokens to burn.
    function safeBurnFrom(address token, address owner, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Burnable.burnFrom.selector, owner, amount));

        if (token.code.length == 0 || !success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }
}

// src/AlchemistV3.sol

/// @title  AlchemistV3
/// @author Alchemix Finance
contract AlchemistV3 is IAlchemistV3, Initializable {
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeCast for int128;
    using SafeCast for uint128;

    uint256 public constant BPS = 10_000;
    uint256 public constant FIXED_POINT_SCALAR = 1e18;

    // Dấu chấm động
    uint256 public constant ONE_Q128 = uint256(1) << 128;//1.0

    /// @inheritdoc IAlchemistV3Immutables
    string public constant version = "3.0.0";

    /// @inheritdoc IAlchemistV3State
    address public admin;

    /// @inheritdoc IAlchemistV3State
    address public alchemistFeeVault;

    /// @inheritdoc IAlchemistV3Immutables
    address public debtToken;

    /// @inheritdoc IAlchemistV3State
    address public myt;

    /// @inheritdoc IAlchemistV3State
    // Thừa số để chuyển đổi giữa debt token và underlying khi chúng có số decimal khác nhau 
    //10^(debtDecimals - underlyingDecimals)
    // 
    uint256 public underlyingConversionFactor;

    /// @inheritdoc IAlchemistV3State
    // Tổng earmark của toàn hệ thống tăng lên khi có earmark và giảm xuống khi đã được re
    uint256 public cumulativeEarmarked;

    /// @inheritdoc IAlchemistV3State
    // Giới hạn tổng số collateral được gửi vào hệ thống 
    uint256 public depositCap;

    /// @inheritdoc IAlchemistV3State
    // Block number của lần earmark gần nhất
    uint256 public lastEarmarkBlock;

    /// @inheritdoc IAlchemistV3State
    //
    uint256 public lastRedemptionBlock;

    /// @inheritdoc IAlchemistV3State
    // Số dư MYT gần nhất được ghi nhận trong transmuter
    uint256 public lastTransmuterTokenBalance;

    /// @inheritdoc IAlchemistV3State
    uint256 public minimumCollateralization;

    /// @inheritdoc IAlchemistV3State
    uint256 public collateralizationLowerBound;

    /// @inheritdoc IAlchemistV3State
    uint256 public globalMinimumCollateralization;

    /// @inheritdoc IAlchemistV3State
    uint256 public totalDebt;

    /// @inheritdoc IAlchemistV3State
    uint256 public totalSyntheticsIssued;

    /// @inheritdoc IAlchemistV3State
    uint256 public protocolFee;

    /// @inheritdoc IAlchemistV3State
    uint256 public liquidatorFee;

    /// @inheritdoc IAlchemistV3State
    uint256 public repaymentFee;

    /// @inheritdoc IAlchemistV3State
    address public alchemistPositionNFT;

    /// @inheritdoc IAlchemistV3State
    address public protocolFeeReceiver;

    /// @inheritdoc IAlchemistV3State
    address public underlyingToken;

    /// @inheritdoc IAlchemistV3State
    address public tokenAdapter;

    /// @inheritdoc IAlchemistV3State
    address public transmuter;

    /// @inheritdoc IAlchemistV3State
    address public pendingAdmin;

    /// @inheritdoc IAlchemistV3State
    bool public depositsPaused;

    /// @inheritdoc IAlchemistV3State
    bool public loansPaused;

    /// @inheritdoc IAlchemistV3State
    mapping(address => bool) public guardians;

    /// @dev Weight of earmarked amount / total unearmarked debt
    uint256 private _earmarkWeight;

    /// @dev Weight of redemption amount / total earmarked debt
    uint256 private _redemptionWeight;

    /// @dev Weight of redeemed collateral and fees / value of total collateral
    uint256 private _collateralWeight;

    /// @dev Earmarked scaled by survival
    uint256 private _survivalAccumulator;

    /// @dev Total locked collateral.
    /// Locked collateral is the collateral that cannot be withdrawn due to LTV constraints
    uint256 private _totalLocked;

    /// @dev Total yield tokens deposited
    /// This is used to differentiate between tokens deposited into a CDP and balance of the contract
    uint256 private _mytSharesDeposited;

    /// @dev User accounts
    mapping(uint256 => Account) private _accounts;

    /// @dev Historic redemptions
    mapping(uint256 => RedemptionInfo) private _redemptions;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyAdminOrGuardian() {
        if (msg.sender != admin && !guardians[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyTransmuter() {
        if (msg.sender != transmuter) {
            revert Unauthorized();
        }
        _;
    }

    constructor() initializer {}

    function initialize(AlchemistInitializationParams memory params) external initializer {
        _checkArgument(params.protocolFee <= BPS);
        _checkArgument(params.liquidatorFee <= BPS);
        _checkArgument(params.repaymentFee <= BPS);

        debtToken = params.debtToken;
        underlyingToken = params.underlyingToken;
        underlyingConversionFactor = 10 ** (TokenUtils.expectDecimals(params.debtToken) - TokenUtils.expectDecimals(params.underlyingToken));
        depositCap = params.depositCap;
        minimumCollateralization = params.minimumCollateralization;
        globalMinimumCollateralization = params.globalMinimumCollateralization;
        collateralizationLowerBound = params.collateralizationLowerBound;
        admin = params.admin;
        transmuter = params.transmuter;
        protocolFee = params.protocolFee;
        protocolFeeReceiver = params.protocolFeeReceiver;
        liquidatorFee = params.liquidatorFee;
        repaymentFee = params.repaymentFee;
        lastEarmarkBlock = block.number;
        lastRedemptionBlock = block.number;
        myt = params.myt;
    }

    /// @notice Emitted when a new Position NFT is minted.
    event AlchemistV3PositionNFTMinted(address indexed to, uint256 indexed tokenId);

    /// @notice Sets the NFT position token, callable by admin.
    function setAlchemistPositionNFT(address nft) external onlyAdmin {
        if (nft == address(0)) {
            revert AlchemistV3NFTZeroAddressError();
        }

        if (alchemistPositionNFT != address(0)) {
            revert AlchemistV3NFTAlreadySetError();
        }

        alchemistPositionNFT = nft;
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setAlchemistFeeVault(address value) external onlyAdmin {
        if (IFeeVault(value).token() != underlyingToken) {
            revert AlchemistVaultTokenMismatchError();
        }
        alchemistFeeVault = value;
        emit AlchemistFeeVaultUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setPendingAdmin(address value) external onlyAdmin {
        pendingAdmin = value;

        emit PendingAdminUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function acceptAdmin() external {
        _checkState(pendingAdmin != address(0));

        if (msg.sender != pendingAdmin) {
            revert Unauthorized();
        }

        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit AdminUpdated(admin);
        emit PendingAdminUpdated(address(0));
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setDepositCap(uint256 value) external onlyAdmin {
        _checkArgument(value >= IERC20_0(myt).balanceOf(address(this)));

        depositCap = value;
        emit DepositCapUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setProtocolFeeReceiver(address value) external onlyAdmin {
        _checkArgument(value != address(0));

        protocolFeeReceiver = value;
        emit ProtocolFeeReceiverUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setProtocolFee(uint256 fee) external onlyAdmin {
        _checkArgument(fee <= BPS);

        protocolFee = fee;
        emit ProtocolFeeUpdated(fee);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setLiquidatorFee(uint256 fee) external onlyAdmin {
        _checkArgument(fee <= BPS);

        liquidatorFee = fee;
        emit LiquidatorFeeUpdated(fee);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setRepaymentFee(uint256 fee) external onlyAdmin {
        _checkArgument(fee <= BPS);

        repaymentFee = fee;
        emit RepaymentFeeUpdated(fee);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setTokenAdapter(address value) external onlyAdmin {
        _checkArgument(value != address(0));

        tokenAdapter = value;
        emit TokenAdapterUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setGuardian(address guardian, bool isActive) external onlyAdmin {
        _checkArgument(guardian != address(0));

        guardians[guardian] = isActive;
        emit GuardianSet(guardian, isActive);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setMinimumCollateralization(uint256 value) external onlyAdmin {
        _checkArgument(value >= FIXED_POINT_SCALAR);
        minimumCollateralization = value;

        emit MinimumCollateralizationUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setGlobalMinimumCollateralization(uint256 value) external onlyAdmin {
        _checkArgument(value >= minimumCollateralization);
        globalMinimumCollateralization = value;
        emit GlobalMinimumCollateralizationUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function setCollateralizationLowerBound(uint256 value) external onlyAdmin {
        _checkArgument(value <= minimumCollateralization);
        _checkArgument(value >= FIXED_POINT_SCALAR);
        collateralizationLowerBound = value;
        emit CollateralizationLowerBoundUpdated(value);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function pauseDeposits(bool isPaused) external onlyAdminOrGuardian {
        depositsPaused = isPaused;
        emit DepositsPaused(isPaused);
    }

    /// @inheritdoc IAlchemistV3AdminActions
    function pauseLoans(bool isPaused) external onlyAdminOrGuardian {
        loansPaused = isPaused;
        emit LoansPaused(isPaused);
    }

    /// @inheritdoc IAlchemistV3State
    function getCDP(uint256 tokenId) external view returns (uint256, uint256, uint256) {
        (uint256 debt, uint256 earmarked, uint256 collateral) = _calculateUnrealizedDebt(tokenId);
        return (collateral, debt, earmarked);
    }

    /// @inheritdoc IAlchemistV3State
    function getTotalDeposited() external view returns (uint256) {
        return IERC20_0(myt).balanceOf(address(this));
    }

    /// @inheritdoc IAlchemistV3State
    function getMaxBorrowable(uint256 tokenId) external view returns (uint256) {
        (uint256 debt,, uint256 collateral) = _calculateUnrealizedDebt(tokenId);
        uint256 debtValueOfCollateral = convertYieldTokensToDebt(collateral);
        uint256 capacity = (debtValueOfCollateral * FIXED_POINT_SCALAR / minimumCollateralization);
        return debt > capacity  ? 0 : capacity - debt;
    }

    /// @inheritdoc IAlchemistV3State
    function mintAllowance(uint256 ownerTokenId, address spender) external view returns (uint256) {
        Account storage account = _accounts[ownerTokenId];
        return account.mintAllowances[account.allowancesVersion][spender];
    }

    /// @inheritdoc IAlchemistV3State
    function getTotalUnderlyingValue() external view returns (uint256) {
        return _getTotalUnderlyingValue();
    }

    /// @inheritdoc IAlchemistV3State
    function totalValue(uint256 tokenId) public view returns (uint256) {
        uint256 totalUnderlying;
        (,, uint256 collateral) = _calculateUnrealizedDebt(tokenId);
        if (collateral > 0) totalUnderlying += convertYieldTokensToUnderlying(collateral);
        return normalizeUnderlyingTokensToDebt(totalUnderlying);
    }

    /// @inheritdoc IAlchemistV3Actions
    function deposit(uint256 amount, address recipient, uint256 tokenId) external returns (uint256) {
        _checkArgument(recipient != address(0));
        _checkArgument(amount > 0);
        _checkState(!depositsPaused);
        _checkState(_mytSharesDeposited + amount <= depositCap);

        // Only mint a new position if the id is 0
        if (tokenId == 0) {
            tokenId = IAlchemistV3Position(alchemistPositionNFT).mint(recipient);
            emit AlchemistV3PositionNFTMinted(recipient, tokenId);
        } else {
            _checkForValidAccountId(tokenId);
        }

        _accounts[tokenId].collateralBalance += amount;

        // Transfer tokens from msg.sender now that the internal storage updates have been committed.
        TokenUtils.safeTransferFrom(myt, msg.sender, address(this), amount);
        _mytSharesDeposited += amount;

        emit Deposit(amount, tokenId);

        return convertYieldTokensToDebt(amount);
    }

    /// @inheritdoc IAlchemistV3Actions
    function withdraw(uint256 amount, address recipient, uint256 tokenId) external returns (uint256) {
        _checkArgument(recipient != address(0));
        _checkForValidAccountId(tokenId);
        _checkArgument(amount > 0);
        _checkAccountOwnership(IAlchemistV3Position(alchemistPositionNFT).ownerOf(tokenId), msg.sender);
        _earmark();

        _sync(tokenId);

        uint256 lockedCollateral = convertDebtTokensToYield(_accounts[tokenId].debt) * minimumCollateralization / FIXED_POINT_SCALAR;
        _checkArgument(_accounts[tokenId].collateralBalance - lockedCollateral >= amount);

        _accounts[tokenId].collateralBalance -= amount;

        // Assure that the collateralization invariant is still held.
        _validate(tokenId);

        // Transfer the yield tokens to msg.sender
        TokenUtils.safeTransfer(myt, recipient, amount);
        _mytSharesDeposited -= amount;

        emit Withdraw(amount, tokenId, recipient);

        return amount;
    }

    /// @inheritdoc IAlchemistV3Actions
    function mint(uint256 tokenId, uint256 amount, address recipient) external {
        _checkArgument(recipient != address(0));
        _checkForValidAccountId(tokenId);
        _checkArgument(amount > 0);
        _checkState(!loansPaused);
        _checkAccountOwnership(IAlchemistV3Position(alchemistPositionNFT).ownerOf(tokenId), msg.sender);

        // Query transmuter and earmark global debt
        _earmark();

        // Sync current user debt before more is taken
        _sync(tokenId);

        // Mint tokens to recipient
        _mint(tokenId, amount, recipient);
    }

    /// @inheritdoc IAlchemistV3Actions
    function mintFrom(uint256 tokenId, uint256 amount, address recipient) external {
        _checkArgument(amount > 0);
        _checkForValidAccountId(tokenId);
        _checkArgument(recipient != address(0));
        _checkState(!loansPaused);
        // Preemptively try and decrease the minting allowance. This will save gas when the allowance is not sufficient.
        _decreaseMintAllowance(tokenId, msg.sender, amount);

        // Query transmuter and earmark global debt
        _earmark();

        // Sync current user debt before more is taken
        _sync(tokenId);

        // Mint tokens from the tokenId's account to the recipient.
        _mint(tokenId, amount, recipient);
    }

    /// @inheritdoc IAlchemistV3Actions
    function burn(uint256 amount, uint256 recipientId) external returns (uint256) {
        _checkArgument(amount > 0);
        _checkForValidAccountId(recipientId);
        // Check that the user did not mint in this same block
        // This is used to prevent flash loan repayments
        if (block.number == _accounts[recipientId].lastMintBlock) revert CannotRepayOnMintBlock();

        // Query transmuter and earmark global debt
        _earmark();

        // Sync current user debt before more is taken
        _sync(recipientId);

        uint256 debt;
        // Burning alAssets can only repay unearmarked debt
        _checkState((debt = _accounts[recipientId].debt - _accounts[recipientId].earmarked) > 0);

        uint256 credit = amount > debt ? debt : amount;

        // Must only burn enough tokens that the transmuter positions can still be fulfilled
        if (credit > totalSyntheticsIssued - ITransmuter(transmuter).totalLocked()) {
            revert BurnLimitExceeded(credit, totalSyntheticsIssued - ITransmuter(transmuter).totalLocked());
        }

        // Burn the tokens from the message sender
        TokenUtils.safeBurnFrom(debtToken, msg.sender, credit);

        // Debt is subject to protocol fee similar to redemptions
        _accounts[recipientId].collateralBalance -= convertDebtTokensToYield(credit) * protocolFee / BPS;
        TokenUtils.safeTransfer(myt, protocolFeeReceiver, convertDebtTokensToYield(credit) * protocolFee / BPS);
        _mytSharesDeposited -= convertDebtTokensToYield(credit) * protocolFee / BPS;

        // Update the recipient's debt.
        _subDebt(recipientId, credit);

        totalSyntheticsIssued -= credit;

        emit Burn(msg.sender, credit, recipientId);

        return credit;
    }

    /// @inheritdoc IAlchemistV3Actions
    function repay(uint256 amount, uint256 recipientTokenId) public returns (uint256) {
        _checkArgument(amount > 0);
        _checkForValidAccountId(recipientTokenId);
        Account storage account = _accounts[recipientTokenId];
        // Check that the user did not mint in this same block
        // This is used to prevent flash loan repayments
        if (block.number == account.lastMintBlock) revert CannotRepayOnMintBlock();

        // Query transmuter and earmark global debt
        _earmark();

        // Sync current user debt before deciding how much is available to be repaid
        _sync(recipientTokenId);

        uint256 debt;

        // Burning yieldTokens will pay off all types of debt
        _checkState((debt = account.debt) > 0);

        uint256 yieldToDebt = convertYieldTokensToDebt(amount);
        uint256 credit = yieldToDebt > debt ? debt : yieldToDebt;
        uint256 creditToYield = convertDebtTokensToYield(credit);

        // Repay debt from earmarked amount of debt first
        uint256 earmarkToRemove = credit > account.earmarked ? account.earmarked : credit;
        account.earmarked -= earmarkToRemove;

        uint256 earmarkPaidGlobal = cumulativeEarmarked > earmarkToRemove ? earmarkToRemove : cumulativeEarmarked;
        cumulativeEarmarked -= earmarkPaidGlobal;

        // Debt is subject to protocol fee similar to redemptions
        uint256 feeAmount = creditToYield * protocolFee / BPS;
        if (feeAmount > account.collateralBalance) {
            revert("Not enough collateral to pay for debt fee");
        } else {
            account.collateralBalance -= creditToYield * protocolFee / BPS;
        }

        _subDebt(recipientTokenId, credit);

        // Transfer the repaid tokens to the transmuter.
        TokenUtils.safeTransferFrom(myt, msg.sender, transmuter, creditToYield);
        TokenUtils.safeTransfer(myt, protocolFeeReceiver, creditToYield * protocolFee / BPS);
        _mytSharesDeposited -= creditToYield * protocolFee / BPS;

        emit Repay(msg.sender, amount, recipientTokenId, creditToYield);

        return creditToYield;
    }

    /// @inheritdoc IAlchemistV3Actions
    function liquidate(uint256 accountId) external override returns (uint256 yieldAmount, uint256 feeInYield, uint256 feeInUnderlying) {
        _checkForValidAccountId(accountId);
        (yieldAmount, feeInYield, feeInUnderlying) = _liquidate(accountId);
        if (yieldAmount > 0) {
            return (yieldAmount, feeInYield, feeInUnderlying);
        } else {
            // no liquidation amount returned, so no liquidation happened
            revert LiquidationError();
        }
    }

    /// @inheritdoc IAlchemistV3Actions
    function batchLiquidate(uint256[] memory accountIds)
        external
        returns (uint256 totalAmountLiquidated, uint256 totalFeesInYield, uint256 totalFeesInUnderlying)
    {
        if (accountIds.length == 0) {
            revert MissingInputData();
        }

        for (uint256 i = 0; i < accountIds.length; i++) {
            uint256 accountId = accountIds[i];
            if (accountId == 0 || !_tokenExists(alchemistPositionNFT, accountId)) {
                continue;
            }
            (uint256 underlyingAmount, uint256 feeInYield, uint256 feeInUnderlying) = _liquidate(accountId);
            totalAmountLiquidated += underlyingAmount;
            totalFeesInYield += feeInYield;
            totalFeesInUnderlying += feeInUnderlying;
        }

        if (totalAmountLiquidated > 0) {
            return (totalAmountLiquidated, totalFeesInYield, totalFeesInUnderlying);
        } else {
            // no total liquidation amount returned, so no liquidations happened
            revert LiquidationError();
        }
    }

    /// @inheritdoc IAlchemistV3Actions
    function redeem(uint256 amount) external onlyTransmuter {
        _earmark();

        uint256 liveEarmarked = cumulativeEarmarked;
        if (amount > liveEarmarked) amount = liveEarmarked;

        // observed transmuter pre-balance -> potential cover
        uint256 transmuterBal = TokenUtils.safeBalanceOf(myt, address(transmuter));
        uint256 deltaYield    = transmuterBal > lastTransmuterTokenBalance ? transmuterBal - lastTransmuterTokenBalance : 0;
        uint256 coverDebt = convertYieldTokensToDebt(deltaYield);

        // cap cover so we never consume beyond remaining earmarked
        uint256 coverToApplyDebt = amount + coverDebt > liveEarmarked ? (liveEarmarked - amount) : coverDebt;

        uint256 redeemedDebtTotal = amount + coverToApplyDebt;

       // Apply redemption weights/decay to the full amount that left the earmarked bucket
        if (liveEarmarked != 0 && redeemedDebtTotal != 0) {
            uint256 survival = ((liveEarmarked - redeemedDebtTotal) << 128) / liveEarmarked;
            _survivalAccumulator = _mulQ128(_survivalAccumulator, survival);
            _redemptionWeight += PositionDecay.WeightIncrement(redeemedDebtTotal, cumulativeEarmarked);
        }

        // earmarks are reduced by the full redeemed amount (net + cover)
        cumulativeEarmarked -= redeemedDebtTotal;

        // global borrower debt falls by the full redeemed amount
        totalDebt -= redeemedDebtTotal;

        lastRedemptionBlock = block.number;

        // consume the observed cover so it can't be reused
        if (deltaYield != 0) {
            uint256 usedYield = convertDebtTokensToYield(coverToApplyDebt);
            lastTransmuterTokenBalance = transmuterBal > usedYield ? transmuterBal - usedYield : transmuterBal;
        }

        // move only the net collateral + fee
        uint256 collRedeemed  = convertDebtTokensToYield(amount);
        uint256 feeCollateral = collRedeemed * protocolFee / BPS;
        uint256 totalOut      = collRedeemed + feeCollateral;

        // update locked collateral + collateral weight
        uint256 old = _totalLocked;
        _totalLocked = totalOut > old ? 0 : old - totalOut;
        _collateralWeight += PositionDecay.WeightIncrement(totalOut > old ? old : totalOut, old);

        TokenUtils.safeTransfer(myt, transmuter, collRedeemed);
        TokenUtils.safeTransfer(myt, protocolFeeReceiver, feeCollateral);
        _mytSharesDeposited -= collRedeemed + feeCollateral;

        emit Redemption(redeemedDebtTotal);
    }

    ///@inheritdoc IAlchemistV3Actions
    function reduceSyntheticsIssued(uint256 amount) external onlyTransmuter {
        totalSyntheticsIssued -= amount;
    }

    ///@inheritdoc IAlchemistV3Actions
    function setTransmuterTokenBalance(uint256 amount) external onlyTransmuter {
        lastTransmuterTokenBalance = amount;
    }

    /// @inheritdoc IAlchemistV3Actions
    function poke(uint256 tokenId) external {
        _checkForValidAccountId(tokenId);
        _earmark();
        _sync(tokenId);
    }

    /// @inheritdoc IAlchemistV3Actions
    function approveMint(uint256 tokenId, address spender, uint256 amount) external {
        _checkAccountOwnership(IAlchemistV3Position(alchemistPositionNFT).ownerOf(tokenId), msg.sender);
        _approveMint(tokenId, spender, amount);
    }

    /// @inheritdoc IAlchemistV3Actions
    function resetMintAllowances(uint256 tokenId) external {
        // Allow calls from either the token owner or the NFT contract
        if (msg.sender != address(alchemistPositionNFT)) {
            // Direct call - verify caller is current owner
            address tokenOwner = IERC721(alchemistPositionNFT).ownerOf(tokenId);
            if (msg.sender != tokenOwner) {
                revert Unauthorized();
            }
        }
        // increment version to start the mapping from a fresh state
        _accounts[tokenId].allowancesVersion += 1;
        // Emit event to notify allowance clearing
        emit MintAllowancesReset(tokenId);
    }

    /// @inheritdoc IAlchemistV3State
    function convertYieldTokensToDebt(uint256 amount) public view returns (uint256) {
        return normalizeUnderlyingTokensToDebt(convertYieldTokensToUnderlying(amount));
    }

    /// @inheritdoc IAlchemistV3State
    function convertDebtTokensToYield(uint256 amount) public view returns (uint256) {
        return convertUnderlyingTokensToYield(normalizeDebtTokensToUnderlying(amount));
    }

    /// @inheritdoc IAlchemistV3State
    function convertYieldTokensToUnderlying(uint256 amount) public view returns (uint256) {
        return IVaultV2(myt).convertToAssets(amount);
    }

    /// @inheritdoc IAlchemistV3State
    function convertUnderlyingTokensToYield(uint256 amount) public view returns (uint256) {
        return IVaultV2(myt).convertToShares(amount);
    }

    /// @inheritdoc IAlchemistV3State
    function normalizeUnderlyingTokensToDebt(uint256 amount) public view returns (uint256) {
        return amount * underlyingConversionFactor;
    }

    /// @inheritdoc IAlchemistV3State
    function normalizeDebtTokensToUnderlying(uint256 amount) public view returns (uint256) {
        return amount / underlyingConversionFactor;
    }

    /// @dev Mints debt tokens to `recipient` using the account owned by `tokenId`.
    /// @param tokenId     The tokenId of the account to mint from.
    /// @param amount    The amount to mint.
    /// @param recipient The recipient of the minted debt tokens.
    function _mint(uint256 tokenId, uint256 amount, address recipient) internal {
        _addDebt(tokenId, amount);

        totalSyntheticsIssued += amount;

        // Validate the tokenId's account to assure that the collateralization invariant is still held.
        _validate(tokenId);

        _accounts[tokenId].lastMintBlock = block.number;

        // Mint the debt tokens to the recipient.
        TokenUtils.safeMint(debtToken, recipient, amount);

        emit Mint(tokenId, amount, recipient);
    }

    /**
     * @notice Force repays earmarked debt of the account owned by `accountId` using account's collateral balance.
     * @param accountId The tokenId of the account to repay from.
     * @param amount The amount to repay in debt tokens.
     * @return creditToYield The amount of yield tokens repaid.
     */
    function _forceRepay(uint256 accountId, uint256 amount) internal returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        _checkForValidAccountId(accountId);
        Account storage account = _accounts[accountId];

        // Query transmuter and earmark global debt
        _earmark();

        // Sync current user debt before deciding how much is available to be repaid
        _sync(accountId);

        uint256 debt;

        // Burning yieldTokens will pay off all types of debt
        _checkState((debt = account.debt) > 0);

        uint256 credit = amount > debt ? debt : amount;
        uint256 creditToYield = convertDebtTokensToYield(credit);
        _subDebt(accountId, credit);

        // Repay debt from earmarked amount of debt first
        uint256 earmarkToRemove = credit > account.earmarked ? account.earmarked : credit;
        account.earmarked -= earmarkToRemove;

        creditToYield = creditToYield > account.collateralBalance ? account.collateralBalance : creditToYield;
        account.collateralBalance -= creditToYield;

        uint256 protocolFeeTotal = creditToYield * protocolFee / BPS;

        emit ForceRepay(accountId, amount, creditToYield, protocolFeeTotal);

        if (account.collateralBalance > protocolFeeTotal) {
            account.collateralBalance -= protocolFeeTotal;
            // Transfer the protocol fee to the protocol fee receiver
            TokenUtils.safeTransfer(myt, protocolFeeReceiver, protocolFeeTotal);
        }

        if (creditToYield > 0) {
            // Transfer the repaid tokens from the account to the transmuter.
            TokenUtils.safeTransfer(myt, address(transmuter), creditToYield);
        }
        return creditToYield;
    }

    /// @dev Fetches and applies the liquidation amount to account `tokenId` if the account collateral ratio touches `collateralizationLowerBound`.
    /// @dev Repays earmarked debt if it exists
    /// @dev If earmarked repayment restores account to healthy collateralization, no liquidation is performed. Caller receives a repayment fee.
    /// @param accountId  The tokenId of the account to to liquidate.
    /// @return amountLiquidated  The amount (in yield tokens) removed from the account `tokenId`.
    /// @return feeInYield The additional fee as a % of the liquidation amount to be sent to the liquidator
    /// @return feeInUnderlying The additional fee as a % of the liquidation amount, denominated in underlying token, to be sent to the liquidator
    function _liquidate(uint256 accountId) internal returns (uint256 amountLiquidated, uint256 feeInYield, uint256 feeInUnderlying) {
        // Query transmuter and earmark global debt
        _earmark();
        // Sync current user debt before deciding how much needs to be liquidated
        _sync(accountId);

        Account storage account = _accounts[accountId];

        // Early return if no debt exists
        if (account.debt == 0) {
            return (0, 0, 0);
        }

        // In the rare scenario where 1 share is worth 0 underlying asset
        if (IVaultV2(myt).convertToAssets(1e18) == 0) {
            return (0, 0, 0);
        }

        // Calculate initial collateralization ratio
        uint256 collateralInUnderlying = totalValue(accountId);
        uint256 collateralizationRatio = collateralInUnderlying * FIXED_POINT_SCALAR / account.debt;

        // If account is healthy, nothing to liquidate
        if (collateralizationRatio > collateralizationLowerBound) {
            return (0, 0, 0);
        }

        // Try to repay earmarked debt if it exists
        uint256 repaidAmountInYield = 0;
        if (account.earmarked > 0) {
            repaidAmountInYield = _forceRepay(accountId, account.earmarked);
        }
        // If debt is fully cleared, return with only the repaid amount, no liquidation needed, caller receives repayment fee
        if (account.debt == 0) {
            feeInYield = _resolveRepaymentFee(accountId, repaidAmountInYield);
            TokenUtils.safeTransfer(myt, msg.sender, feeInYield);
            return (repaidAmountInYield, feeInYield, 0);
        }

        // Recalculate ratio after any repayment to determine if further liquidation is needed
        collateralInUnderlying = totalValue(accountId);
        collateralizationRatio = collateralInUnderlying * FIXED_POINT_SCALAR / account.debt;

        if (collateralizationRatio <= collateralizationLowerBound) {
            // Do actual liquidation
            return _doLiquidation(accountId, collateralInUnderlying, repaidAmountInYield);
        } else {
            // Since only a repayment happened, send repayment fee to caller
            feeInYield = _resolveRepaymentFee(accountId, repaidAmountInYield);
            TokenUtils.safeTransfer(myt, msg.sender, feeInYield);
            return (repaidAmountInYield, feeInYield, 0);
        }
    }

    /// @dev Performs the actual liquidation logic when collateralization is below the lower bound
    /// @param accountId The tokenId of the account to to liquidate.
    /// @param collateralInUnderlying The total collateral value of the account in debt tokens.
    /// @param repaidAmountInYield The amount of debt repaid in yield tokens.
    /// @return amountLiquidated The amount of yield tokens liquidated.
    /// @return feeInYield The fee in yield tokens to be sent to the liquidator.
    /// @return feeInUnderlying The fee in underlying tokens to be sent to the liquidator.
    function _doLiquidation(uint256 accountId, uint256 collateralInUnderlying, uint256 repaidAmountInYield)
        internal
        returns (uint256 amountLiquidated, uint256 feeInYield, uint256 feeInUnderlying)
    {
        Account storage account = _accounts[accountId];

        (uint256 liquidationAmount, uint256 debtToBurn, uint256 baseFee, uint256 outsourcedFee) = calculateLiquidation(
            collateralInUnderlying,
            account.debt,
            minimumCollateralization,
            normalizeUnderlyingTokensToDebt(_getTotalUnderlyingValue()) * FIXED_POINT_SCALAR / totalDebt,
            globalMinimumCollateralization,
            liquidatorFee
        );

        amountLiquidated = convertDebtTokensToYield(liquidationAmount);
        feeInYield = convertDebtTokensToYield(baseFee);

        // update user balance and debt
        account.collateralBalance = account.collateralBalance > amountLiquidated ? account.collateralBalance - amountLiquidated : 0;
        _subDebt(accountId, debtToBurn);

        // send liquidation amount - fee to transmuter
        TokenUtils.safeTransfer(myt, transmuter, amountLiquidated - feeInYield);

        // send base fee to liquidator if available
        if (feeInYield > 0 && account.collateralBalance >= feeInYield) {
            TokenUtils.safeTransfer(myt, msg.sender, feeInYield);
        }

        // Handle outsourced fee from vault
        if (outsourcedFee > 0) {
            uint256 vaultBalance = IFeeVault(alchemistFeeVault).totalDeposits();
            if (vaultBalance > 0) {
                uint256 feeBonus = normalizeDebtTokensToUnderlying(outsourcedFee);
                feeInUnderlying = vaultBalance > feeBonus ? feeBonus : vaultBalance;
                IFeeVault(alchemistFeeVault).withdraw(msg.sender, feeInUnderlying);
            }
        }

        emit Liquidated(accountId, msg.sender, amountLiquidated + repaidAmountInYield, feeInYield, feeInUnderlying);
        return (amountLiquidated + repaidAmountInYield, feeInYield, feeInUnderlying);
    }

    /// @dev Handles repayment fee calculation and account deduction
    /// @param accountId The tokenId of the account to force a repayment on.
    /// @param repaidAmountInYield The amount of debt repaid in yield tokens.
    /// @return fee The fee in yield tokens to be sent to the liquidator.
    function _resolveRepaymentFee(uint256 accountId, uint256 repaidAmountInYield) internal returns (uint256 fee) {
        Account storage account = _accounts[accountId];
        // calculate repayment fee and deduct from account
        fee = repaidAmountInYield * repaymentFee / BPS;
        account.collateralBalance -= fee > account.collateralBalance ? account.collateralBalance : fee;
        emit RepaymentFee(accountId, repaidAmountInYield, msg.sender, fee);
        return fee;
    }

    /// @dev Increases the debt by `amount` for the account owned by `tokenId`.
    ///
    /// @param tokenId   The account owned by tokenId.
    /// @param amount  The amount to increase the debt by.
    function _addDebt(uint256 tokenId, uint256 amount) internal {
        Account storage account = _accounts[tokenId];

        // Update collateral variables
        uint256 toLock = convertDebtTokensToYield(amount) * minimumCollateralization / FIXED_POINT_SCALAR;
        uint256 lockedCollateral = convertDebtTokensToYield(account.debt) * minimumCollateralization / FIXED_POINT_SCALAR;

        if (account.collateralBalance - lockedCollateral < toLock) revert Undercollateralized();

        account.rawLocked = lockedCollateral + toLock;
        _totalLocked += toLock;
        account.debt += amount;
        totalDebt += amount;
    }

    /// @dev Subtracts the debt by `amount` for the account owned by `tokenId`.
    ///
    /// @param tokenId   The account owned by tokenId.
    /// @param amount  The amount to decrease the debt by.
    function _subDebt(uint256 tokenId, uint256 amount) internal {
      // tokenID = 1
      // amount = 1000
        Account storage account = _accounts[tokenId]; // account {.....}

        // Update collateral variables
        // 1000 * 1000/10000
        uint256 toFree = convertDebtTokensToYield(amount) * minimumCollateralization / FIXED_POINT_SCALAR;
        // 2000 * debt/ 10000
        uint256 lockedCollateral = convertDebtTokensToYield(account.debt) * minimumCollateralization / FIXED_POINT_SCALAR;

        // For cases when someone above minimum LTV gets liquidated.
        if (toFree > _totalLocked) {
            toFree = _totalLocked;
        }

        account.debt -= amount; // 2000 - 1000
        totalDebt -= amount; // 10000 - 1000
        _totalLocked -= toFree; // 10000 - 1000
        account.rawLocked = lockedCollateral - toFree; //1000
 
        // Clamp to avoid underflow due to rounding later at a later time
        if (cumulativeEarmarked > totalDebt) {
            cumulativeEarmarked = totalDebt; 
        }
    }

    /// @dev Set the mint allowance for `spender` to `amount` for the account owned by `tokenId`.
    ///
    /// @param ownerTokenId   The id of the account granting approval.
    /// @param spender The address of the spender.
    /// @param amount  The amount of debt tokens to set the mint allowance to.
    function _approveMint(uint256 ownerTokenId, address spender, uint256 amount) internal {
        Account storage account = _accounts[ownerTokenId];
        account.mintAllowances[account.allowancesVersion][spender] = amount;
        emit ApproveMint(ownerTokenId, spender, amount);
    }

    /// @dev Decrease the mint allowance for `spender` by `amount` for the account owned by `ownerTokenId`.
    ///
    /// @param ownerTokenId The id of the account owner.
    /// @param spender The address of the spender.
    /// @param amount  The amount of debt tokens to decrease the mint allowance by.
    function _decreaseMintAllowance(uint256 ownerTokenId, address spender, uint256 amount) internal {
        Account storage account = _accounts[ownerTokenId];
        account.mintAllowances[account.allowancesVersion][spender] -= amount;
    }

    /// @dev Checks an expression and reverts with an {IllegalArgument} error if the expression is {false}.
    ///
    /// @param expression The expression to check.
    function _checkArgument(bool expression) internal pure {
        if (!expression) {
            revert IllegalArgument();
        }
    }

    /// @dev Checks if owner == sender and reverts with an {UnauthorizedAccountAccessError} error if the result is {false}.
    ///
    /// @param owner The address of the owner of an account.
    /// @param user The address of the user attempting to access an account.
    function _checkAccountOwnership(address owner, address user) internal pure {
        if (owner != user) {
            revert UnauthorizedAccountAccessError();
        }
    }

    /// @dev reverts {UnknownAccountOwnerIDError} error by if no owner exists.
    ///
    /// @param tokenId The id of an account.
    function _checkForValidAccountId(uint256 tokenId) internal view {
        if (!_tokenExists(alchemistPositionNFT, tokenId)) {
            revert UnknownAccountOwnerIDError();
        }
    }

    /**
     * @notice Checks whether a token id is linked to an owner. Non blocking / no reverts.
     * @param nft The address of the ERC721 based contract.
     * @param tokenId The token id to check.
     * @return exists A boolean that is true if the token exists.
     */
    function _tokenExists(address nft, uint256 tokenId) internal view returns (bool exists) {
        if (tokenId == 0) {
            // token ids start from 1
            return false;
        }
        try IERC721(nft).ownerOf(tokenId) {
            // If the call succeeds, the token exists.
            exists = true;
        } catch {
            // If the call fails, then the token does not exist.
            exists = false;
        }
    }

    /// @dev Checks an expression and reverts with an {IllegalState} error if the expression is {false}.
    ///
    /// @param expression The expression to check.
    function _checkState(bool expression) internal pure {
        if (!expression) {
            revert IllegalState();
        }
    }

    /// @dev Checks that the account owned by `tokenId` is properly collateralized.
    /// @dev If the account is undercollateralized then this will revert with an {Undercollateralized} error.
    ///
    /// @param tokenId The id of the account owner.
    function _validate(uint256 tokenId) internal view {
        if (_isUnderCollateralized(tokenId)) revert Undercollateralized();
    }

    /// @dev Update the user's earmarked and redeemed debt amounts.
    function _sync(uint256 tokenId) internal {
        Account storage account = _accounts[tokenId];

        // Collateral to remove from redemptions and fees
        uint256 collateralToRemove = PositionDecay.ScaleByWeightDelta(account.rawLocked, _collateralWeight - account.lastCollateralWeight);
        account.collateralBalance -= collateralToRemove;

        // Redemption survival now and at last sync
        // Survival is the amount of earmark that is left after a redemption
        uint256 redemptionSurvivalOld = PositionDecay.SurvivalFromWeight(account.lastAccruedRedemptionWeight);
        if (redemptionSurvivalOld == 0) redemptionSurvivalOld = ONE_Q128;
        uint256 redemptionSurvivalNew  = PositionDecay.SurvivalFromWeight(_redemptionWeight);
        // Survival during current sync window
        uint256 survivalRatio = _divQ128(redemptionSurvivalNew, redemptionSurvivalOld);
        // User exposure at last sync used to calculate newly earmarked debt pre redemption
        uint256 userExposure = account.debt > account.earmarked ? account.debt - account.earmarked : 0;
        uint256 earmarkRaw = PositionDecay.ScaleByWeightDelta(userExposure, _earmarkWeight - account.lastAccruedEarmarkWeight);

        // Earmark survival at last sync
        // Survival is the amount of unearmarked debt left after an earmark
        uint256 earmarkSurvival = PositionDecay.SurvivalFromWeight(account.lastAccruedEarmarkWeight);
        if (earmarkSurvival == 0) earmarkSurvival = ONE_Q128;
        // Decay snapshot by what was redeemed from last sync until now
        uint256 decayedRedeemed = _mulQ128(account.lastSurvivalAccumulator, survivalRatio);
        // What was added to the survival accumulator in the current sync window
        uint256 survivalDiff = _survivalAccumulator > decayedRedeemed ? _survivalAccumulator - decayedRedeemed : 0;

        // Unwind accumulated earmarked at last sync
        uint256 unredeemedRatio = _divQ128(survivalDiff, earmarkSurvival);
        // Portion of earmark that remains after applying the redemption. Scaled back from 128.128
        uint256 earmarkedUnredeemed = _mulQ128(userExposure, unredeemedRatio);
        if (earmarkedUnredeemed > earmarkRaw) earmarkedUnredeemed = earmarkRaw;

        // Old earmarks that survived redemptions in the current sync window
        uint256 exposureSurvival = _mulQ128(account.earmarked, survivalRatio);
        // What was redeemed from the newly earmark between last sync and now
        uint256 redeemedFromEarmarked = earmarkRaw - earmarkedUnredeemed;
        // Total overall earmarked to adjust user debt
        uint256 redeemedTotal = (account.earmarked - exposureSurvival) + redeemedFromEarmarked;

        account.earmarked = exposureSurvival + earmarkedUnredeemed;
        account.debt = account.debt >= redeemedTotal ? account.debt - redeemedTotal : 0;

        // Update locked collateral
        account.rawLocked = convertDebtTokensToYield(account.debt) * minimumCollateralization / FIXED_POINT_SCALAR;

        // Advance account checkpoint
        account.lastCollateralWeight = _collateralWeight;
        account.lastAccruedEarmarkWeight = _earmarkWeight;
        account.lastAccruedRedemptionWeight = _redemptionWeight;

        // Snapshot G for this account
        account.lastSurvivalAccumulator = _survivalAccumulator;
    }

    /// @dev Earmarks the debt for redemption.
    function _earmark() internal {
        if (totalDebt == 0) return;
        if (block.number <= lastEarmarkBlock) return;

        // Yield the transmuter accumulated since last earmark (cover)
        uint256 transmuterCurrentBalance = TokenUtils.safeBalanceOf(myt, address(transmuter));
        uint256 transmuterDifference = transmuterCurrentBalance > lastTransmuterTokenBalance ? transmuterCurrentBalance - lastTransmuterTokenBalance : 0;

        uint256 amount = ITransmuter(transmuter).queryGraph(lastEarmarkBlock + 1, block.number);

        // Proper saturating subtract in DEBT units
        uint256 coverInDebt = convertYieldTokensToDebt(transmuterDifference);
        amount = amount > coverInDebt ? amount - coverInDebt : 0;

        lastTransmuterTokenBalance = transmuterCurrentBalance;

        uint256 liveUnearmarked = totalDebt - cumulativeEarmarked;
        if (amount > liveUnearmarked) amount = liveUnearmarked;

        if (amount > 0 && liveUnearmarked != 0) {
            // Previous earmark survival
            uint256 previousSurvival = PositionDecay.SurvivalFromWeight(_earmarkWeight);
            if (previousSurvival == 0) previousSurvival = ONE_Q128;

            // Fraction of unearmarked debt being earmarked now in UQ128.128
            uint256 earmarkedFraction = _divQ128(amount, liveUnearmarked);

            _survivalAccumulator += _mulQ128(previousSurvival, earmarkedFraction);
            _earmarkWeight += PositionDecay.WeightIncrement(amount, liveUnearmarked);

            cumulativeEarmarked += amount;
        }

        lastEarmarkBlock = block.number;
    }

    /// @dev Gets the amount of debt that the account owned by `owner` will have after a sync occurs.
    ///
    /// @param tokenId The id of the account owner.
    ///
    /// @return The amount of debt that the account owned by `owner` will have after an update.
    /// @return The amount of debt which is currently earmarked fro redemption.
    /// @return The amount of collateral that has yet to be redeemed.
    function _calculateUnrealizedDebt(uint256 tokenId)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        Account storage account = _accounts[tokenId];

        // Local copies
        uint256 earmarkWeightCopy = _earmarkWeight;
        uint256 survivalAccumulatorCopy   = _survivalAccumulator;

        // Simulate earmark since lastEarmarkBlock
        if (block.number > lastEarmarkBlock) {
            uint256 transmuterCurrentBalance = TokenUtils.safeBalanceOf(myt, address(transmuter));
            uint256 transmuterDifference = transmuterCurrentBalance > lastTransmuterTokenBalance ? transmuterCurrentBalance - lastTransmuterTokenBalance : 0;

            uint256 amount = ITransmuter(transmuter).queryGraph(lastEarmarkBlock + 1, block.number);

            // cover in DEBT units
            uint256 coverInDebt = convertYieldTokensToDebt(transmuterDifference);
            amount = amount > coverInDebt ? amount - coverInDebt : 0;

            uint256 liveUnearmarked = totalDebt - cumulativeEarmarked;
            if (amount > liveUnearmarked) amount = liveUnearmarked;

            if (amount > 0 && liveUnearmarked != 0) {
                // Previous earmark survival
                uint256 previousSurvival = PositionDecay.SurvivalFromWeight(earmarkWeightCopy);
                if (previousSurvival == 0) previousSurvival = ONE_Q128;

                // Fraction of unearmarked debt being earmarked now in UQ128.128
                uint256 earmarkedFraction = _divQ128(amount, liveUnearmarked);

                survivalAccumulatorCopy += _mulQ128(previousSurvival, earmarkedFraction);
                earmarkWeightCopy += PositionDecay.WeightIncrement(amount, liveUnearmarked);
            }
        }

        // Redemption survival now and at last sync
        // Survival is the amount of earmark that is left after a redemption
        uint256 redemptionSurvivalOld = PositionDecay.SurvivalFromWeight(account.lastAccruedRedemptionWeight);
        if (redemptionSurvivalOld == 0) redemptionSurvivalOld = ONE_Q128;
        uint256 redemptionSurvivalNew  = PositionDecay.SurvivalFromWeight(_redemptionWeight);
        // Survival during the current sync window
        uint256 survivalRatio = _divQ128(redemptionSurvivalNew, redemptionSurvivalOld);

        // User exposure at last sync used to calculate newly earmarked debt pre redemption
        uint256 userExposure = account.debt > account.earmarked ? account.debt - account.earmarked : 0;
        uint256 earmarkRaw = PositionDecay.ScaleByWeightDelta(userExposure, earmarkWeightCopy - account.lastAccruedEarmarkWeight);

        // Earmark survival at last sync
        // Survival is the amount of unearmarked debt left after an earmark
        uint256 earmarkSurvival = PositionDecay.SurvivalFromWeight(account.lastAccruedEarmarkWeight);
        if (earmarkSurvival == 0) earmarkSurvival = ONE_Q128;
        // Decay snapshot by what was redeemed from last sync until now
        uint256 decayedRedeemed = _mulQ128(account.lastSurvivalAccumulator, survivalRatio);
        // What was added to the survival accumulator in the current sync window
        uint256 survivalDiff  = survivalAccumulatorCopy > decayedRedeemed ? survivalAccumulatorCopy - decayedRedeemed : 0;

        // Unwind accumulated earmarked at last sync
        uint256 unredeemedRatio = _divQ128(survivalDiff, earmarkSurvival);
        // Portion of earmark that remains after applying the redemption. Scaled back from 128.128
        uint256 earmarkedUnredeemed = _mulQ128(userExposure, unredeemedRatio);
        if (earmarkedUnredeemed > earmarkRaw) earmarkedUnredeemed = earmarkRaw;

        // Old earmarks that survived redemptions in the current sync window
        uint256 exposureSurvival = _mulQ128(account.earmarked, survivalRatio);

        // What was redeemed from the newly earmark between last sync and now
        uint256 redeemedFromEarmarked = earmarkRaw - earmarkedUnredeemed;
        // Total overall earmarked to adjust user debt
        uint256 redeemedTotal = (account.earmarked - exposureSurvival) + redeemedFromEarmarked;

        uint256 newDebt = account.debt >= redeemedTotal ? account.debt - redeemedTotal : 0;
        uint256 newEarmarked = exposureSurvival + earmarkedUnredeemed;

        // Collateral from fees and redemptions
        uint256 collateralToRemove = PositionDecay.ScaleByWeightDelta(account.rawLocked, _collateralWeight - account.lastCollateralWeight);
        uint256 newCollateral = account.collateralBalance - collateralToRemove;

        return (newDebt, newEarmarked, newCollateral);
    }

    /// @dev Checks that the account owned by `tokenId` is properly collateralized.
    /// @dev Returns true only if the account is undercollateralized
    ///
    /// @param tokenId The id of the account owner.
    function _isUnderCollateralized(uint256 tokenId) internal view returns (bool) {
        uint256 debt = _accounts[tokenId].debt;
        if (debt == 0) return false;

        uint256 collateralization = totalValue(tokenId) * FIXED_POINT_SCALAR / debt;
        return collateralization < minimumCollateralization;
    }

    /// @dev Calculates the total value of the alchemist in the underlying token.
    /// @return totalUnderlyingValue The total value of the alchemist in the underlying token.
    function _getTotalUnderlyingValue() internal view returns (uint256 totalUnderlyingValue) {
        uint256 yieldTokenTVLInUnderlying = convertYieldTokensToUnderlying(_mytSharesDeposited);
        totalUnderlyingValue = yieldTokenTVLInUnderlying;
    }

    /// @inheritdoc IAlchemistV3State
    function calculateLiquidation(
        uint256 collateral,
        uint256 debt,
        uint256 targetCollateralization,
        uint256 alchemistCurrentCollateralization,
        uint256 alchemistMinimumCollateralization,
        uint256 feeBps
    ) public pure returns (uint256 grossCollateralToSeize, uint256 debtToBurn, uint256 fee, uint256 outsourcedFee) {
        if (debt >= collateral) {
            outsourcedFee = (debt * feeBps) / BPS;
            // fully liquidate debt if debt is greater than collateral
            return (collateral, debt, 0, outsourcedFee);
        }

        if (alchemistCurrentCollateralization < alchemistMinimumCollateralization) {
            outsourcedFee = (debt * feeBps) / BPS;
            // fully liquidate debt in high ltv global environment
            return (debt, debt, 0, outsourcedFee);
        }

        // fee is taken from surplus = collateral - debt
        uint256 surplus = collateral > debt ? collateral - debt : 0;

        fee = (surplus * feeBps) / BPS;

        // collateral remaining for margin‐restore calc
        uint256 adjCollat = collateral - fee;

        // compute m*d  (both plain units)
        uint256 md = (targetCollateralization * debt) / FIXED_POINT_SCALAR;

        // if md <= adjCollat, nothing to liquidate
        if (md <= adjCollat) {
            return (0, 0, fee, 0);
        }

        // numerator = md - adjCollat
        uint256 num = md - adjCollat;

        // denom = m - 1  =>  (targetCollateralization - FIXED_POINT_SCALAR)/FIXED_POINT_SCALAR
        uint256 denom = targetCollateralization - FIXED_POINT_SCALAR;

        // debtToBurn = (num * FIXED_POINT_SCALAR) / denom
        debtToBurn = (num * FIXED_POINT_SCALAR) / denom;

        // gross collateral seize = net + fee
        grossCollateralToSeize = debtToBurn + fee;
    }

    // Math helpers for Q128.128
    function _mulQ128(uint256 aQ, uint256 bQ) private pure returns (uint256 z) {
        if (aQ == 0 || bQ == 0) return 0;
        uint256 lo;
        uint256 hi;
        assembly {
            // 512-bit product [hi lo] = aQ * bQ
            let mm := mulmod(aQ, bQ, not(0))
            lo := mul(aQ, bQ)
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
        // floor((a*b) / 2^128)
        z = (hi << 128) | (lo >> 128);
        // if there are non-zero low bits, round up
        if (lo & ((uint256(1) << 128) - 1) != 0) {
            unchecked {
                z += 1;
            }
        }
    }

    function _divQ128(uint256 numerQ128, uint256 denomQ128) private pure returns (uint256) {
        if (numerQ128 == 0) return 0;
        unchecked {
            // Fast path: shifting is safe if numerQ128 < 2^128
            if (numerQ128 <= type(uint256).max >> 128) {
                return (numerQ128 << 128) / denomQ128;
            }
            // Slow path: numerQ128 can only be 2^128 here.
            uint256 q = numerQ128 / denomQ128; // 0 or 1 in our domain
            uint256 r = numerQ128 - q * denomQ128; // remainder
            return (q << 128) + ((r << 128) / denomQ128);
        }
    }
}

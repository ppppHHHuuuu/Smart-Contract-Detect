// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;

/**
 * @title BiFi's marketManager contract
 * @notice Implement business logic and manage handlers
 * @author BiFi(seinmyung25, Miller-kk, tlatkdgus1, dongchangYoo)
 */
contract TokenManager is ManagerSlot {

	/**
	* @dev Constructor for marketManager
	* @param managerDataStorageAddr The address of the manager storage contract
	* @param oracleProxyAddr The address of oracle proxy contract (e.g., price feeds)
	* @param breaker The address of default circuit breaker
	* @param erc20Addr The address of reward token (ERC-20)
	*/
	constructor (address managerDataStorageAddr, address oracleProxyAddr, address _slotSetterAddr, address _handlerManagerAddr, address _flashloanAddr, address breaker, address erc20Addr) public
	{
		owner = msg.sender;
		dataStorageInstance = IManagerDataStorage(managerDataStorageAddr);
		oracleProxy = IOracleProxy(oracleProxyAddr);
		rewardErc20Instance = IERC20(erc20Addr);

		slotSetterAddr = _slotSetterAddr;
		handlerManagerAddr = _handlerManagerAddr;
		flashloanAddr = _flashloanAddr;

		breakerTable[owner].auth = true;
		breakerTable[breaker].auth = true;
	}

	/**
	* @dev Transfer ownership
	* @param _owner the address of the new owner
	* @return result the setter call in contextSetter contract
	*/
	function ownershipTransfer(address payable _owner) onlyOwner public returns (bool result) {
    bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.ownershipTransfer.selector,
				_owner
			);

    (result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	function setOperator(address payable adminAddr, bool flag) onlyOwner external returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setOperator.selector,
				adminAddr, flag
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Set the address of OracleProxy contract
	* @param oracleProxyAddr The address of OracleProxy contract
	* @return result the setter call in contextSetter contract
	*/
	function setOracleProxy(address oracleProxyAddr) onlyOwner external returns (bool result) {
    bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setOracleProxy.selector,
				oracleProxyAddr
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Set the address of BiFi reward token contract
	* @param erc20Addr The address of BiFi reward token contract
	* @return result the setter call in contextSetter contract
	*/
	function setRewardErc20(address erc20Addr) onlyOwner public returns (bool result) {
    bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setRewardErc20.selector,
				erc20Addr
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Authorize admin user for circuitBreaker
	* @param _target The address of the circuitBreaker admin user.
	* @param _status The boolean status of circuitBreaker (on/off)
	* @return result the setter call in contextSetter contract
	*/
	function setBreakerTable(address _target, bool _status) onlyOwner external returns (bool result) {
    bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setBreakerTable.selector,
				_target, _status
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Set circuitBreak to freeze/unfreeze all handlers
	* @param _emergency The boolean status of circuitBreaker (on/off)
	* @return result the setter call in contextSetter contract
	*/
	function setCircuitBreaker(bool _emergency) onlyBreaker external returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setCircuitBreaker.selector,
				_emergency
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	function setPositionStorageAddr(address _positionStorageAddr) onlyOwner external returns (bool result) {
			bytes memory callData = abi.encodeWithSelector(
					IManagerSlotSetter.setPositionStorageAddr.selector,
					_positionStorageAddr
				);

			(result, ) = slotSetterAddr.delegatecall(callData);
		assert(result);
	}

	function setNFTAddr(address _nftAddr) onlyOwner external returns (bool result) {
			bytes memory callData = abi.encodeWithSelector(
					IManagerSlotSetter.setNFTAddr.selector,
					_nftAddr
				);

			(result, ) = slotSetterAddr.delegatecall(callData);
		assert(result);
	}

	function setDiscountBase(uint256 handlerID, uint256 feeBase) onlyOwner external returns (bool result) {
			bytes memory callData = abi.encodeWithSelector(
					IManagerSlotSetter
					.setDiscountBase.selector,
					handlerID,
			feeBase
				);

			(result, ) = slotSetterAddr.delegatecall(callData);
		assert(result);
	}

	/**
	* @dev Get the circuitBreak status
	* @return The circuitBreak status
	*/
	function getCircuitBreaker() external view returns (bool)
	{
		return emergency;
	}

	/**
	* @dev Get information for a handler
	* @param handlerID Handler ID
	* @return (success or failure, handler address, handler name)
	*/
	function getTokenHandlerInfo(uint256 handlerID) external view returns (bool, address, string memory)
	{
		bool support;
		address tokenHandlerAddr;
		string memory tokenName;
		if (dataStorageInstance.getTokenHandlerSupport(handlerID))
		{
			tokenHandlerAddr = dataStorageInstance.getTokenHandlerAddr(handlerID);
			IProxy TokenHandler = IProxy(tokenHandlerAddr);
			bytes memory data;
			(, data) = TokenHandler.handlerViewProxy(
				abi.encodeWithSelector(
					IMarketHandler
					.getTokenName.selector
				)
			);
			tokenName = abi.decode(data, (string));
			support = true;
		}

		return (support, tokenHandlerAddr, tokenName);
	}

	/**
	* @dev Register a handler
	* @param handlerID Handler ID and address
	* @param tokenHandlerAddr The handler address
	* @return result the setter call in contextSetter contract
	*/
	function handlerRegister(uint256 handlerID, address tokenHandlerAddr, uint256 flashFeeRate, uint256 discountBase) onlyOwner external returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
					IManagerSlotSetter
					.handlerRegister.selector,
					handlerID, tokenHandlerAddr, flashFeeRate, discountBase
				);

			(result, ) = slotSetterAddr.delegatecall(callData);
		assert(result);
	}
	/**
	* @dev Set a liquidation manager contract
	* @param liquidationManagerAddr The address of liquidiation manager
	* @return result the setter call in contextSetter contract
	*/
	function setLiquidationManager(address liquidationManagerAddr) onlyOwner external returns (bool result) {
    bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setLiquidationManager.selector,
				liquidationManagerAddr
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Update the (SI) rewards for a user
	* @param userAddr The address of the user
	* @param callerID The handler ID
	* @return true (TODO: validate results)
	*/
	function rewardUpdateOfInAction(address payable userAddr, uint256 callerID) external returns (bool)
	{
		ContractInfo memory handlerInfo;
		(handlerInfo.support, handlerInfo.addr) = dataStorageInstance.getTokenHandlerInfo(callerID);
		if (handlerInfo.support)
		{
			IProxy TokenHandler;
			TokenHandler = IProxy(handlerInfo.addr);
			TokenHandler.siProxy(
				abi.encodeWithSelector(
					IServiceIncentive
					.updateRewardLane.selector,
					userAddr
				)
			);
		}

		return true;
	}

	/**
	* @dev Update interest of a user for a handler (internal)
	* @param userAddr The user address
	* @param callerID The handler ID
	* @param allFlag Flag for the full calculation mode (calculting for all handlers)
	* @return (uint256, uint256, uint256, uint256, uint256, uint256)
	*/
	function applyInterestHandlers(address payable userAddr, uint256 callerID, bool allFlag) external returns (uint256, uint256, uint256, uint256, uint256, uint256) {
    bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.applyInterestHandlers.selector,
				userAddr, callerID, allFlag
			);

		(bool result, bytes memory returnData) = handlerManagerAddr.delegatecall(callData);
    assert(result);

    return abi.decode(returnData, (uint256, uint256, uint256, uint256, uint256, uint256));
  }

	/**
	* @dev Reward the user (msg.sender) with the reward token after calculating interest.
	* @return result the interestUpdateReward call in ManagerInterest contract
	*/
	function interestUpdateReward() external returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.interestUpdateReward.selector
			);

		(result, ) = handlerManagerAddr.delegatecall(callData);
    	assert(result);
	}

	/**
	* @dev (Update operation) update the rewards parameters.
	* @param userAddr The address of operator
	* @return result the updateRewardParams call in ManagerInterest contract
	*/
	function updateRewardParams(address payable userAddr) onlyOperators external returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.updateRewardParams.selector,
        userAddr
			);

		(result, ) = handlerManagerAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Claim all rewards for the user
	* @param userAddr The user address
	* @return true (TODO: validate results)
	*/
	function rewardClaimAll(address payable userAddr) external returns (uint256)
	{
    bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.rewardClaimAll.selector,
        userAddr
			);

		(bool result, bytes memory returnData) = handlerManagerAddr.delegatecall(callData);
    assert(result);

    return abi.decode(returnData, (uint256));
	}

	/**
	* @dev Claim handler rewards for the user
	* @param handlerID The ID of claim reward handler
	* @param userAddr The user address
	* @return true (TODO: validate results)
	*/
	function claimHandlerReward(uint256 handlerID, address payable userAddr) external returns (uint256) {
		bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.claimHandlerReward.selector,
        handlerID, userAddr
			);

		(bool result, bytes memory returnData) = handlerManagerAddr.delegatecall(callData);
    assert(result);

    return abi.decode(returnData, (uint256));
	}

	/**
	* @dev Transfer reward tokens to owner (for administration)
	* @param _amount The amount of the reward token
	* @return result (TODO: validate results)
	*/
	function ownerRewardTransfer(uint256 _amount) onlyOwner external returns (bool result)
	{
		bytes memory callData = abi.encodeWithSelector(
				IHandlerManager
				.ownerRewardTransfer.selector,
        _amount
			);

		(result, ) = handlerManagerAddr.delegatecall(callData);
    assert(result);
	}


	/**
	* @dev Get the token price of the handler
	* @param handlerID The handler ID
	* @return The token price of the handler
	*/
	function getTokenHandlerPrice(uint256 handlerID) external view returns (uint256)
	{
		return _getTokenHandlerPrice(handlerID);
	}

	/**
	* @dev Get the margin call limit of the handler (external)
	* @param handlerID The handler ID
	* @return The margin call limit
	*/
	function getTokenHandlerMarginCallLimit(uint256 handlerID) external view returns (uint256)
	{
		return _getTokenHandlerMarginCallLimit(handlerID);
	}

	/**
	* @dev Get the margin call limit of the handler (internal)
	* @param handlerID The handler ID
	* @return The margin call limit
	*/
	function _getTokenHandlerMarginCallLimit(uint256 handlerID) internal view returns (uint256)
	{
		IProxy TokenHandler = IProxy(dataStorageInstance.getTokenHandlerAddr(handlerID));
		bytes memory data;
		(, data) = TokenHandler.handlerViewProxy(
			abi.encodeWithSelector(
				IMarketHandler
				.getTokenHandlerMarginCallLimit.selector
			)
		);
		return abi.decode(data, (uint256));
	}

	/**
	* @dev Get the borrow limit of the handler (external)
	* @param handlerID The handler ID
	* @return The borrow limit
	*/
	function getTokenHandlerBorrowLimit(uint256 handlerID) external view returns (uint256)
	{
		return _getTokenHandlerBorrowLimit(handlerID);
	}

	/**
	* @dev Get the borrow limit of the handler (internal)
	* @param handlerID The handler ID
	* @return The borrow limit
	*/
	function _getTokenHandlerBorrowLimit(uint256 handlerID) internal view returns (uint256)
	{
		IProxy TokenHandler = IProxy(dataStorageInstance.getTokenHandlerAddr(handlerID));

		bytes memory data;
		(, data) = TokenHandler.handlerViewProxy(
			abi.encodeWithSelector(
				IMarketHandler
				.getTokenHandlerBorrowLimit.selector
			)
		);
		return abi.decode(data, (uint256));
	}

	/**
	* @dev Get the handler status of whether the handler is supported or not.
	* @param handlerID The handler ID
	* @return Whether the handler is supported or not
	*/
	function getTokenHandlerSupport(uint256 handlerID) external view returns (bool)
	{
		return dataStorageInstance.getTokenHandlerSupport(handlerID);
	}

	/**
	* @dev Set the length of the handler list
	* @param _tokenHandlerLength The length of the handler list
	* @return true (TODO: validate results)
	*/
	function setTokenHandlersLength(uint256 _tokenHandlerLength) onlyOwner external returns (bool)
	{
		tokenHandlerLength = _tokenHandlerLength;
		return true;
	}

	/**
	* @dev Get the length of the handler list
	* @return the length of the handler list
	*/
	function getTokenHandlersLength() external view returns (uint256)
	{
		return tokenHandlerLength;
	}

	/**
	* @dev Get the handler ID at the index in the handler list
	* @param index The index of the handler list (array)
	* @return The handler ID
	*/
	function getTokenHandlerID(uint256 index) external view returns (uint256)
	{
		return dataStorageInstance.getTokenHandlerID(index);
	}

	/**
	* @dev Get the amount of token that the user can borrow more
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The amount of token that user can borrow more
	*/
	function getUserExtraLiquidityAmount(address payable userAddr, uint256 handlerID) external view returns (uint256)
	{
		return _getUserExtraLiquidityAmount(userAddr, handlerID);
	}

	/**
	* @dev Get the deposit and borrow amount of the user with interest added
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The deposit and borrow amount of the user with interest
	*/
	/* about user market Information function*/
	function getUserIntraHandlerAssetWithInterest(address payable userAddr, uint256 handlerID) external view returns (uint256, uint256)
	{
		return _getUserIntraHandlerAssetWithInterest(userAddr, handlerID);
	}

	/**
	* @dev Get the depositTotalCredit and borrowTotalCredit
	* @param userAddr The address of the user
	* @return depositTotalCredit The amount that users can borrow (i.e. deposit * borrowLimit)
	* @return borrowTotalCredit The sum of borrow amount for all handlers
	*/
	function getUserTotalIntraCreditAsset(address payable userAddr) external view returns (uint256, uint256)
	{
		return _getUserTotalIntraCreditAsset(userAddr);
	}

	/**
	* @dev Get the borrow and margin call limits of the user for all handlers
	* @param userAddr The address of the user
	* @return userTotalBorrowLimitAsset the sum of borrow limit for all handlers
	* @return userTotalMarginCallLimitAsset the sume of margin call limit for handlers
	*/
	function getUserLimitIntraAsset(address payable userAddr) external view returns (uint256, uint256)
	{
		uint256 userTotalBorrowLimitAsset;
		uint256 userTotalMarginCallLimitAsset;

		for (uint256 handlerID; handlerID < tokenHandlerLength; handlerID++)
		{
			if (dataStorageInstance.getTokenHandlerSupport(handlerID))
			{
				uint256 depositHandlerAsset;
				uint256 borrowHandlerAsset;
				(depositHandlerAsset, borrowHandlerAsset) = _getUserIntraHandlerAssetWithInterest(userAddr, handlerID);
				uint256 borrowLimit = _getTokenHandlerBorrowLimit(handlerID);
				uint256 marginCallLimit = _getTokenHandlerMarginCallLimit(handlerID);
				uint256 userBorrowLimitAsset = depositHandlerAsset.unifiedMul(borrowLimit);
				uint256 userMarginCallLimitAsset = depositHandlerAsset.unifiedMul(marginCallLimit);
				userTotalBorrowLimitAsset = userTotalBorrowLimitAsset.add(userBorrowLimitAsset);
				userTotalMarginCallLimitAsset = userTotalMarginCallLimitAsset.add(userMarginCallLimitAsset);
			}
			else
			{
				continue;
			}

		}

		return (userTotalBorrowLimitAsset, userTotalMarginCallLimitAsset);
	}


	/**
	* @dev Get the maximum allowed amount to borrow of the user from the given handler
	* @param userAddr The address of the user
	* @param callerID The target handler to borrow
	* @return extraCollateralAmount The maximum allowed amount to borrow from
	  the handler.
	*/
	function getUserCollateralizableAmount(address payable userAddr, uint256 callerID) external view returns (uint256)
	{
		uint256 userTotalBorrowAsset;
		uint256 depositAssetBorrowLimitSum;
		uint256 depositHandlerAsset;
		uint256 borrowHandlerAsset;
		for (uint256 handlerID; handlerID < tokenHandlerLength; handlerID++)
		{
			if (dataStorageInstance.getTokenHandlerSupport(handlerID))
			{

				(depositHandlerAsset, borrowHandlerAsset) = _getUserIntraHandlerAssetWithInterest(userAddr, handlerID);
				userTotalBorrowAsset = userTotalBorrowAsset.add(borrowHandlerAsset);
				depositAssetBorrowLimitSum = depositAssetBorrowLimitSum
												.add(
													depositHandlerAsset
													.unifiedMul( _getTokenHandlerBorrowLimit(handlerID) )
												);
			}
		}

		if (depositAssetBorrowLimitSum > userTotalBorrowAsset)
		{
			return depositAssetBorrowLimitSum
					.sub(userTotalBorrowAsset)
					.unifiedDiv( _getTokenHandlerBorrowLimit(callerID) )
					.unifiedDiv( _getTokenHandlerPrice(callerID) );
		}
		return 0;
	}

	/**
	* @dev Partial liquidation for a user
	* @param delinquentBorrower The address of the liquidation target
	* @param liquidateAmount The amount to liquidate
	* @param liquidator The address of the liquidator (liquidation operator)
	* @param liquidateHandlerID The hander ID of the liquidating asset
	* @param rewardHandlerID The handler ID of the reward token for the liquidator
	* @return (uint256, uint256, uint256)
	*/
	function partialLiquidationUser(address payable delinquentBorrower, uint256 liquidateAmount, address payable liquidator, uint256 liquidateHandlerID, uint256 rewardHandlerID) onlyLiquidationManager external returns (uint256, uint256, uint256)
	{
		address tokenHandlerAddr = dataStorageInstance.getTokenHandlerAddr(liquidateHandlerID);
		IProxy TokenHandler = IProxy(tokenHandlerAddr);
		bytes memory data;

		data = abi.encodeWithSelector(
			IMarketHandler
			.partialLiquidationUser.selector,

			delinquentBorrower,
			liquidateAmount,
			liquidator,
			rewardHandlerID
		);
		(, data) = TokenHandler.handlerProxy(data);

		return abi.decode(data, (uint256, uint256, uint256));
	}

	/**
	* @dev Get the maximum liquidation reward by checking sufficient reward
	  amount for the liquidator.
	* @param delinquentBorrower The address of the liquidation target
	* @param liquidateHandlerID The hander ID of the liquidating asset
	* @param liquidateAmount The amount to liquidate
	* @param rewardHandlerID The handler ID of the reward token for the liquidator
	* @param rewardRatio delinquentBorrowAsset / delinquentDepositAsset
	* @return The maximum reward token amount for the liquidator
	*/
	function getMaxLiquidationReward(address payable delinquentBorrower, uint256 liquidateHandlerID, uint256 liquidateAmount, uint256 rewardHandlerID, uint256 rewardRatio) external view returns (uint256)
	{
		uint256 liquidatePrice = _getTokenHandlerPrice(liquidateHandlerID);
		uint256 rewardPrice = _getTokenHandlerPrice(rewardHandlerID);
		uint256 delinquentBorrowerRewardDeposit;
		(delinquentBorrowerRewardDeposit, ) = _getHandlerAmount(delinquentBorrower, rewardHandlerID);
		uint256 rewardAsset = delinquentBorrowerRewardDeposit.unifiedMul(rewardPrice).unifiedMul(rewardRatio);
		if (liquidateAmount.unifiedMul(liquidatePrice) > rewardAsset)
		{
			return rewardAsset.unifiedDiv(liquidatePrice);
		}
		else
		{
			return liquidateAmount;
		}

	}

	/**
	* @dev Reward the liquidator
	* @param delinquentBorrower The address of the liquidation target
	* @param rewardAmount The amount of reward token
	* @param liquidator The address of the liquidator (liquidation operator)
	* @param handlerID The handler ID of the reward token for the liquidator
	* @return The amount of reward token
	*/
	function partialLiquidationUserReward(address payable delinquentBorrower, uint256 rewardAmount, address payable liquidator, uint256 handlerID) onlyLiquidationManager external returns (uint256)
	{
		address tokenHandlerAddr = dataStorageInstance.getTokenHandlerAddr(handlerID);
		IProxy TokenHandler = IProxy(tokenHandlerAddr);
		bytes memory data;
		data = abi.encodeWithSelector(
			IMarketHandler
			.partialLiquidationUserReward.selector,

			delinquentBorrower,
			rewardAmount,
			liquidator
		);
		(, data) = TokenHandler.handlerProxy(data);

		return abi.decode(data, (uint256));
	}

	/**
    * @dev Execute flashloan contract with delegatecall
    * @param handlerID The ID of the token handler to borrow.
    * @param receiverAddress The address of receive callback contract
    * @param amount The amount of borrow through flashloan
    * @param params The encode metadata of user
    * @return Whether or not succeed
    */
 	function flashloan(
      uint256 handlerID,
      address receiverAddress,
      uint256 amount,
      bytes calldata params
    ) external returns (bool) {
      bytes memory callData = abi.encodeWithSelector(
				IManagerFlashloan
				.flashloan.selector,
				handlerID, receiverAddress, amount, params
			);

      (bool result, bytes memory returnData) = flashloanAddr.delegatecall(callData);
      assert(result);

      return abi.decode(returnData, (bool));
    }

	/**
	* @dev Call flashloan logic contract with delegatecall
    * @param handlerID The ID of handler with accumulated flashloan fee
    * @return The amount of fee accumlated to handler
    */
 	function getFeeTotal(uint256 handlerID) external returns (uint256)
	{
		bytes memory callData = abi.encodeWithSelector(
				IManagerFlashloan
				.getFeeTotal.selector,
				handlerID
			);

		(bool result, bytes memory returnData) = flashloanAddr.delegatecall(callData);
		assert(result);

		return abi.decode(returnData, (uint256));
    }

	/**
    * @dev Withdraw accumulated flashloan fee with delegatecall
    * @param handlerID The ID of handler with accumulated flashloan fee
    * @return Whether or not succeed
    */
	function withdrawFlashloanFee(
      uint256 handlerID
    ) external onlyOwner returns (bool) {
    	bytes memory callData = abi.encodeWithSelector(
				IManagerFlashloan
				.withdrawFlashloanFee.selector,
				handlerID
			);

		(bool result, bytes memory returnData) = flashloanAddr.delegatecall(callData);
		assert(result);

		return abi.decode(returnData, (bool));
    }

  /**
    * @dev Get flashloan fee for flashloan amount before make product(BiFi-X)
    * @param handlerID The ID of handler with accumulated flashloan fee
    * @param amount The amount of flashloan amount
    * @param bifiAmount The amount of Bifi amount
    * @return The amount of fee for flashloan amount
    */
  function getFeeFromArguments(
      uint256 handlerID,
      uint256 amount,
      uint256 bifiAmount
    ) external returns (uint256) {
      bytes memory callData = abi.encodeWithSelector(
				IManagerFlashloan
				.getFeeFromArguments.selector,
				handlerID, amount, bifiAmount
			);

      (bool result, bytes memory returnData) = flashloanAddr.delegatecall(callData);
      assert(result);

      return abi.decode(returnData, (uint256));
    }

	/**
	* @dev Get the deposit and borrow amount of the user for the handler (internal)
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The deposit and borrow amount
	*/
	function _getHandlerAmount(address payable userAddr, uint256 handlerID) internal view returns (uint256, uint256)
	{
		IProxy TokenHandler = IProxy(dataStorageInstance.getTokenHandlerAddr(handlerID));
		bytes memory data;
		(, data) = TokenHandler.handlerViewProxy(
			abi.encodeWithSelector(
				IMarketHandler
				.getUserAmount.selector,
				userAddr
			)
		);
		return abi.decode(data, (uint256, uint256));
	}

  	/**
	* @dev Get the deposit and borrow amount with interest of the user for the handler (internal)
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The deposit and borrow amount with interest
	*/
	function _getHandlerAmountWithAmount(address payable userAddr, uint256 handlerID) internal view returns (uint256, uint256)
	{
		IProxy TokenHandler = IProxy(dataStorageInstance.getTokenHandlerAddr(handlerID));
		bytes memory data;
		(, data) = TokenHandler.handlerViewProxy(
			abi.encodeWithSelector(
				IMarketHandler
				.getUserAmountWithInterest.selector,
				userAddr
			)
		);
		return abi.decode(data, (uint256, uint256));
	}

	/**
	* @dev Set the support stauts for the handler
	* @param handlerID the handler ID
	* @param support the support status (boolean)
	* @return result the setter call in contextSetter contract
	*/
	function setHandlerSupport(uint256 handlerID, bool support) onlyOwner public returns (bool result) {
		bytes memory callData = abi.encodeWithSelector(
				IManagerSlotSetter
				.setHandlerSupport.selector,
				handlerID, support
			);

		(result, ) = slotSetterAddr.delegatecall(callData);
    assert(result);
	}

	/**
	* @dev Get owner's address of the manager contract
	* @return The address of owner
	*/
	function getOwner() public view returns (address)
	{
		return owner;
	}

	/**
	* @dev Get the deposit and borrow amount of the user with interest added
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The deposit and borrow amount of the user with interest
	*/
	function _getUserIntraHandlerAssetWithInterest(address payable userAddr, uint256 handlerID) internal view returns (uint256, uint256)
	{
		uint256 price = _getTokenHandlerPrice(handlerID);
		IProxy TokenHandler = IProxy(dataStorageInstance.getTokenHandlerAddr(handlerID));
		uint256 depositAmount;
		uint256 borrowAmount;

		bytes memory data;
		(, data) = TokenHandler.handlerViewProxy(
			abi.encodeWithSelector(
				IMarketHandler.getUserAmountWithInterest.selector,
				userAddr
			)
		);
		(depositAmount, borrowAmount) = abi.decode(data, (uint256, uint256));

		uint256 depositAsset = depositAmount.unifiedMul(price);
		uint256 borrowAsset = borrowAmount.unifiedMul(price);
		return (depositAsset, borrowAsset);
	}

	/**
	* @dev Get the depositTotalCredit and borrowTotalCredit
	* @param userAddr The address of the user
	* @return depositTotalCredit The amount that users can borrow (i.e. deposit * borrowLimit)
	* @return borrowTotalCredit The sum of borrow amount for all handlers
	*/
	function _getUserTotalIntraCreditAsset(address payable userAddr) internal view returns (uint256, uint256)
	{
		uint256 depositTotalCredit;
		uint256 borrowTotalCredit;
		for (uint256 handlerID; handlerID < tokenHandlerLength; handlerID++)
		{
			if (dataStorageInstance.getTokenHandlerSupport(handlerID))
			{
				uint256 depositHandlerAsset;
				uint256 borrowHandlerAsset;
				(depositHandlerAsset, borrowHandlerAsset) = _getUserIntraHandlerAssetWithInterest(userAddr, handlerID);
				uint256 borrowLimit = _getTokenHandlerBorrowLimit(handlerID);
				uint256 depositHandlerCredit = depositHandlerAsset.unifiedMul(borrowLimit);
				depositTotalCredit = depositTotalCredit.add(depositHandlerCredit);
				borrowTotalCredit = borrowTotalCredit.add(borrowHandlerAsset);
			}
			else
			{
				continue;
			}

		}

		return (depositTotalCredit, borrowTotalCredit);
	}

	/**
	* @dev Get the amount of token that the user can borrow more
	* @param userAddr The address of user
	* @param handlerID The handler ID
	* @return The amount of token that user can borrow more
	*/
  	function _getUserExtraLiquidityAmount(address payable userAddr, uint256 handlerID) internal view returns (uint256) {
		uint256 depositCredit;
		uint256 borrowCredit;
		(depositCredit, borrowCredit) = _getUserTotalIntraCreditAsset(userAddr);
		if (depositCredit == 0)
		{
			return 0;
		}

		if (depositCredit > borrowCredit)
		{
			return depositCredit.sub(borrowCredit).unifiedDiv(_getTokenHandlerPrice(handlerID));
		}
		else
		{
			return 0;
		}
	}

	function getFeePercent(uint256 handlerID) external view returns (uint256)
	{
	return handlerFlashloan[handlerID].flashFeeRate;
	}

	/**
	* @dev Get the token price for the handler
	* @param handlerID The handler id
	* @return The token price of the handler
	*/
	function _getTokenHandlerPrice(uint256 handlerID) internal view returns (uint256)
	{
		return (oracleProxy.getTokenPrice(handlerID));
	}

	/**
	* @dev Get the address of reward token
	* @return The address of reward token
	*/
	function getRewardErc20() public view returns (address)
	{
		return address(rewardErc20Instance);
	}

	/**
	* @dev Get the reward parameters
	* @return (uint256,uint256,uint256) rewardPerBlock, rewardDecrement, rewardTotalAmount
	*/
	function getGlobalRewardInfo() external view returns (uint256, uint256, uint256)
	{
		IManagerDataStorage _dataStorage = dataStorageInstance;
		return (_dataStorage.getGlobalRewardPerBlock(), _dataStorage.getGlobalRewardDecrement(), _dataStorage.getGlobalRewardTotalAmount());
	}

	function setObserverAddr(address observerAddr) onlyOwner external returns (bool) {
		Observer = IObserver( observerAddr );
	}

	/**
	* @dev fallback function where handler can receive native coin
	*/
	fallback () external payable
	{

	}
}
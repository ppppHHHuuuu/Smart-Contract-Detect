// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;


/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}


/**
 * @title WhitelistAdminRole
 * @dev WhitelistAdmins are responsible for assigning and removing Whitelisted accounts.
 */
contract WhitelistAdminRole {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(msg.sender);
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(msg.sender));
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(msg.sender);
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}


interface ERC20fraction {
  function decimals() external view returns (uint8);
}

interface AggregatorFraction {
  function decimals() external view returns (uint8);
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
}


/**
 * @title ChainlinkConversionPath
 *
 * @notice ChainlinkConversionPath is a contract allowing to compute conversion rate from a Chainlink aggretators
 */
contract ChainlinkConversionPath is WhitelistAdminRole {
  using SafeMath for uint256;

  uint constant DECIMALS = 1e18;

  // Mapping of Chainlink aggregators (input currency => output currency => contract address)
  // input & output currencies are the addresses of the ERC20 contracts OR the sha3("currency code")
  mapping(address => mapping(address => address)) public allAggregators;

  // declare a new aggregator
  event AggregatorUpdated(address _input, address _output, address _aggregator);

  /**
    * @notice Update an aggregator
    * @param _input address representing the input currency
    * @param _output address representing the output currency
    * @param _aggregator address of the aggregator contract
  */
  function updateAggregator(address _input, address _output, address _aggregator)
    external
    onlyWhitelistAdmin
  {
    allAggregators[_input][_output] = _aggregator;
    emit AggregatorUpdated(_input, _output, _aggregator);
  }

  /**
    * @notice Update a list of aggregators
    * @param _inputs list of addresses representing the input currencies
    * @param _outputs list of addresses representing the output currencies
    * @param _aggregators list of addresses of the aggregator contracts
  */
  function updateAggregatorsList(address[] calldata _inputs, address[] calldata _outputs, address[] calldata _aggregators)
    external
    onlyWhitelistAdmin
  {
    require(_inputs.length == _outputs.length, "arrays must have the same length");
    require(_inputs.length == _aggregators.length, "arrays must have the same length");

    // For every conversions of the path
    for (uint i; i < _inputs.length; i++) {
      allAggregators[_inputs[i]][_outputs[i]] = _aggregators[i];
      emit AggregatorUpdated(_inputs[i], _outputs[i], _aggregators[i]);
    }
  }

  /**
  * @notice Computes the conversion from an amount through a list of conversion
  * @param _amountIn Amount to convert
  * @param _path List of addresses representing the currencies for the conversions
  * @return result the result after all the conversion
  * @return oldestRateTimestamp he oldest timestamp of the path
  */
  function getConversion(
    uint256 _amountIn,
    address[] calldata _path
  )
    external
    view
    returns (uint256 result, uint256 oldestRateTimestamp)
  {
    (uint256 rate, uint256 timestamp, uint256 decimals) = getRate(_path);

    // initialize the result
    result = _amountIn.mul(rate).div(decimals);

    oldestRateTimestamp = timestamp;
  }

  /**
  * @notice Computes the rate from a list of conversion
  * @param _path List of addresses representing the currencies for the conversions
  * @return rate the rate
  * @return oldestRateTimestamp he oldest timestamp of the path
  * @return decimals of the conversion rate
  */
  function getRate(
    address[] memory _path
  )
    public
    view
    returns (uint256 rate, uint256 oldestRateTimestamp, uint256 decimals)
  {
    // initialize the result with 1e18 decimals (for more precision)
    rate = DECIMALS;
    decimals = DECIMALS;
    oldestRateTimestamp = block.timestamp;

    // For every conversions of the path
    for (uint i; i < _path.length - 1; i++) {
      (AggregatorFraction aggregator, bool reverseAggregator, uint256 decimalsInput, uint256 decimalsOutput) = getAggregatorAndDecimals(_path[i], _path[i + 1]);

      // store the latest timestamp of the path
      uint256 currentTimestamp = aggregator.latestTimestamp();
      if (currentTimestamp < oldestRateTimestamp) {
        oldestRateTimestamp = currentTimestamp;
      }

      // get the rate of the current step
      uint256 currentRate = uint256(aggregator.latestAnswer());
      // get the number of decimal of the current rate
      uint256 decimalsAggregator = uint256(aggregator.decimals());

      // mul with the difference of decimals before the current rate computation (for more precision)
      if (decimalsAggregator > decimalsInput) {
        rate = rate.mul(10**(decimalsAggregator-decimalsInput));
      }
      if (decimalsAggregator < decimalsOutput) {
        rate = rate.mul(10**(decimalsOutput-decimalsAggregator));
      }

      // Apply the current rate (if path uses an aggregator in the reverse way, div instead of mul)
      if (reverseAggregator) {
        rate = rate.mul(10**decimalsAggregator).div(currentRate);
      } else {
        rate = rate.mul(currentRate).div(10**decimalsAggregator);
      }

      // div with the difference of decimals AFTER the current rate computation (for more precision)
      if (decimalsAggregator < decimalsInput) {
        rate = rate.div(10**(decimalsInput-decimalsAggregator));
      }
      if (decimalsAggregator > decimalsOutput) {
        rate = rate.div(10**(decimalsAggregator-decimalsOutput));
      }
    }
  }

  /**
  * @notice Gets aggregators and decimals of two currencies
  * @param _input input Address
  * @param _output output Address
  * @return aggregator to get the rate between the two currencies
  * @return reverseAggregator true if the aggregator returned give the rate from _output to _input
  * @return decimalsInput decimals of _input
  * @return decimalsOutput decimals of _output
  */
  function getAggregatorAndDecimals(address _input, address _output)
    private
    view
    returns (AggregatorFraction aggregator, bool reverseAggregator, uint256 decimalsInput, uint256 decimalsOutput)
  {
    // Try to get the right aggregator for the conversion
    aggregator = AggregatorFraction(allAggregators[_input][_output]);
    reverseAggregator = false;

    // if no aggregator found we try to find an aggregator in the reverse way
    if (address(aggregator) == address(0x00)) {
      aggregator = AggregatorFraction(allAggregators[_output][_input]);
      reverseAggregator = true;
    }

    require(address(aggregator) != address(0x00), "No aggregator found");

    // get the decimals for the two currencies
    decimalsInput = getDecimals(_input);
    decimalsOutput = getDecimals(_output);
  }

  /**
  * @notice Gets decimals from an address currency
  * @param _addr address to check
  * @return number of decimals
  */
  function getDecimals(address _addr)
    private
    view
    returns (uint256 decimals)
  {
    // by default we assume it is FIAT so 8 decimals
    decimals = 8;
    // if address is 0, then it's ETH
    if (_addr == address(0x0)) {
      decimals = 18;
    } else if (isContract(_addr)) {
      // otherwise, we get the decimals from the erc20 directly
      decimals = ERC20fraction(_addr).decimals();
    }
  }

  /**
  * @notice Checks if an address is a contract
  * @param _addr Address to check
  * @return true if the address host a contract, false otherwise
  */
  function isContract(address _addr)
    private
    view
    returns (bool)
  {
    uint32 size;
    // solium-disable security/no-inline-assembly
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }
}

interface IERC20FeeProxy {
  event TransferWithReferenceAndFee(
    address tokenAddress,
    address to,
    uint256 amount,
    bytes indexed paymentReference,
    uint256 feeAmount,
    address feeAddress
  );

  function transferFromWithReferenceAndFee(
    address _tokenAddress,
    address _to,
    uint256 _amount,
    bytes calldata _paymentReference,
    uint256 _feeAmount,
    address _feeAddress
    ) external;
}


/**
 * @title ERC20ConversionProxy
 */
contract ERC20ConversionProxy {
  using SafeMath for uint256;

  address public paymentProxy;
  ChainlinkConversionPath public chainlinkConversionPath;

  constructor(address _paymentProxyAddress, address _chainlinkConversionPathAddress) public {
    paymentProxy = _paymentProxyAddress;
    chainlinkConversionPath = ChainlinkConversionPath(_chainlinkConversionPathAddress);
  }

  // Event to declare a transfer with a reference
  event TransferWithConversionAndReference(
    uint256 amount,
    address currency,
    bytes indexed paymentReference,
    uint256 feeAmount,
    uint256 maxRateTimespan
  );

  /**
   * @notice Performs an ERC20 token transfer with a reference computing the amount based on a fiat amount
   * @param _to Transfer recipient
   * @param _requestAmount request amount
   * @param _path conversion path
   * @param _paymentReference Reference of the payment related
   * @param _feeAmount The amount of the payment fee
   * @param _feeAddress The fee recipient
   * @param _maxToSpend amount max that we can spend on the behalf of the user
   * @param _maxRateTimespan max time span with the oldestrate, ignored if zero
   */
  function transferFromWithReferenceAndFee(
    address _to,
    uint256 _requestAmount,
    address[] calldata _path,
    bytes calldata _paymentReference,
    uint256 _feeAmount,
    address _feeAddress,
    uint256 _maxToSpend,
    uint256 _maxRateTimespan
  ) external
  {
    (uint256 amountToPay, uint256 amountToPayInFees) = getConversions(_path, _requestAmount, _feeAmount, _maxRateTimespan);

    require(amountToPay.add(amountToPayInFees) <= _maxToSpend, "Amount to pay is over the user limit");

    // Pay the request and fees
    (bool status, ) = paymentProxy.delegatecall(
      abi.encodeWithSignature(
        "transferFromWithReferenceAndFee(address,address,uint256,bytes,uint256,address)",
        // payment currency
        _path[_path.length - 1],
        _to,
        amountToPay,
        _paymentReference,
        amountToPayInFees,
        _feeAddress
      )
    );
    require(status, "transferFromWithReferenceAndFee failed");

    // Event to declare a transfer with a reference
    emit TransferWithConversionAndReference(
      _requestAmount,
      // request currency
      _path[0],
      _paymentReference,
      _feeAmount,
      _maxRateTimespan
    );
  }

  function getConversions(
    address[] memory _path,
    uint256 _requestAmount,
    uint256 _feeAmount,
    uint256 _maxRateTimespan
  ) internal
    returns (uint256 amountToPay, uint256 amountToPayInFees)
  {
    (uint256 rate, uint256 oldestTimestampRate, uint256 decimals) = chainlinkConversionPath.getRate(_path);

    // Check rate timespan
    require(_maxRateTimespan == 0 || block.timestamp.sub(oldestTimestampRate) <= _maxRateTimespan, "aggregator rate is outdated");
    
    // Get the amount to pay in the crypto currency chosen
    amountToPay = _requestAmount.mul(rate).div(decimals);
    amountToPayInFees = _feeAmount.mul(rate).div(decimals);
  }
}
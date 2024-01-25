pragma solidity 0.7.5;

// Inheritance







/// @title   UMB to NFT swapping contract
/// @author  umb.network
contract NFTRewards is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public umbToken;
    address public leftoverReceiver;
    uint256 public multiplier;
    uint256 public rewardsDeadline;

    mapping(address => uint) public balances;

    constructor(address _umbToken, address _leftoverReceiver) {
        require(_umbToken != address(0x0), "should be non-null UMB token address");
        require(_leftoverReceiver != address(0x0), "should be non-null leftoverReceiver address");

        umbToken = _umbToken;
        leftoverReceiver = _leftoverReceiver;
    }

    function balanceOf(address _addr) view public returns(uint256) {
        return balances[_addr].mul(multiplier);
    }

    function startRewards(
        uint _multiplier,
        address[] calldata _addresses,
        uint[] calldata _balances,
        uint _duration
    ) external onlyOwner {
        require(_duration > 0, "duration should be positive");
        require(rewardsDeadline == 0, "can start rewards one time");
        require(_multiplier > 0, "multiplier must be positive");
        require(_addresses.length > 0, "should be at least 1 address");
        require(_addresses.length == _balances.length, "should be the same number of addresses and balances");

        for (uint i = 0; i < _addresses.length; i++) {
            balances[_addresses[i]] = _balances[i];
        }

        multiplier = _multiplier;
        rewardsDeadline = block.timestamp + _duration;
    }

    function close() external {
        require(block.timestamp > rewardsDeadline, "cannot close the contract right now");

        uint umbBalance = IERC20(umbToken).balanceOf(address(this));

        if (umbBalance > 0) {
            require(IERC20(umbToken).transfer(leftoverReceiver, umbBalance), "transfer failed");
        }

        selfdestruct(msg.sender);
    }

    function claimUMB() external {
        uint nftAmount = balances[msg.sender];
        require(nftAmount > 0, "amount should be positive");

        balances[msg.sender] = 0;

        uint umbAmount = nftAmount.mul(multiplier);

        IERC20(umbToken).safeTransfer(msg.sender, umbAmount);

        emit Claimed(msg.sender, nftAmount, umbAmount);
    }

    event Claimed(
        address indexed receiver,
        uint nftAmount,
        uint umbAmount);
}
pragma solidity ^0.5.0;



/**
 * @title An amazing project called mulit_transfer
 * @dev This contract is the base of our project
 */
contract MultiTransfer is Ownable{

    address public tokenAddress;
    uint256 public minThreshold;
    address public collector;
    mapping(address => bool) public whitelists;

    constructor (address _tokenAddress,
                 address _collector,
                 uint256 _minThreshold) public {
        require(_tokenAddress != address(0) && _collector != address(0) && _minThreshold > 0, "invalid params");
        tokenAddress = _tokenAddress;
        collector = _collector;
        minThreshold = _minThreshold;
        whitelists[msg.sender] = true;
        whitelists[collector] = true;
    }

    function() external payable {}

    function transferToken(address _from, uint256 _amount) internal {
        require(_from != address(0) && _amount >= minThreshold , "invalid from or amount");
        IERC20(tokenAddress).transferFrom(_from, collector, _amount);
    }

    function multiTransferToken(address[] memory _froms, uint256[] memory _amounts) public {
        require(_froms.length == _amounts.length, "invalid transfer token counts");
        for(uint256 i = 0; i<_froms.length; i++ ){
            transferToken(_froms[i], _amounts[i]);
        }
    }

    function multiTransferETH(address[] memory _receives, uint256[] memory _amounts) public {
        require(whitelists[msg.sender], "invalid sender");
        require(_receives.length == _amounts.length, "invalid transfer eth counts");

        uint256 count = 0;
        uint256 i = 0;

        for(i = 0; i < _amounts.length; i++){
            count += _amounts[i];
        }
        require(address(this).balance >= count, "contract balance not enough");

        for(i = 0; i < _receives.length; i++){
            address payable receiver = address(uint160(_receives[i]));
            receiver.transfer(_amounts[i]);
        }
    }

    function configureThreshold(uint256 _minThreshold) public onlyOwner {
        require(_minThreshold > 0, "invalid threshold");
        minThreshold = _minThreshold;
    }

    function modifyTokenAddress(address _tokenAddress) public onlyOwner{
        require(_tokenAddress != address(0), "invalid token address");
        tokenAddress = _tokenAddress;
    }

    function modifyCollector(address _collector) public onlyOwner {
        require(_collector != address(0), "invalid collector address");
        collector = _collector;
    }

    function modifyWhitelist(address _user, bool _isWhite) public onlyOwner {
        require(_user != address(0), "invalid user");
        whitelists[_user] = _isWhite;
    }

    function claimTokens(address _token) public onlyOwner {
        if (_token == address(0)) {
            address payable owner = address(uint160(owner()));
            owner.transfer(address(this).balance);
            return;
        }
        IERC20 erc20token = IERC20(_token);
        uint256 balance = erc20token.balanceOf(address(this));
        erc20token.transfer(owner(), balance);
    }

}
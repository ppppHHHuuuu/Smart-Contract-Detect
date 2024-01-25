contract DtktSale is Claimable {
    using SafeMath for uint256;

    struct Sale {
        uint startTime;
        uint endTime;
        uint minPurchase;
        uint weiRaised;
    }

    struct Fees {
        uint fund;
        uint reward;
        uint divisor;
    }

    struct Wallets {
        address fund;
        address fees;
    }

    uint public era;
    Fees public fees;
    Wallets public wallets;
    mapping(uint => Sale) public sales;
    mapping(address => uint) public balances;

    event NewSale(uint era, uint startTime, uint endTime, uint minPurchase);
    event NewFees(uint fund, uint reward, uint divisor);
    event NewWallets(address fund, address fees);
    event Purchase(uint indexed era, address indexed wallet, uint amount);
    event Reward(address indexed affiliate, uint amount);
    event Withdraw(address indexed wallet, uint amount);

		function HoduSale() public {
			//set default
			updateWallets(msg.sender, msg.sender);
			updateFees(4, 1, 100);
		}

    function () public payable {
        if (msg.value > 0) {
            buy();
        } else {
            claim();
        }
    }

    function buy() public payable {
        buyWithReward(wallets.fees);
    }

    function buyWithReward(address affiliate) whenFunding public payable {
        Sale storage sale = sales[era];
        require(msg.value >= sale.minPurchase);

        require(affiliate != msg.sender);
        require(affiliate != address(this));

        uint fee = msg.value.mul(fees.fund).div(fees.divisor);
        uint reward = msg.value.mul(fees.reward).div(fees.divisor);
        uint amount = msg.value.sub(fee).sub(reward);

        balances[wallets.fees] = balances[wallets.fees].add(fee);
        balances[affiliate] = balances[affiliate].add(reward);
        balances[wallets.fund] = balances[wallets.fund].add(amount);

        sale.weiRaised = sale.weiRaised.add(amount);

        Purchase(era, msg.sender, amount);
        Reward(affiliate, reward);
    }

    function claim() public {
        if (msg.sender == wallets.fees || msg.sender == wallets.fund) require(!funding());
        uint payment = balances[msg.sender];
        require(payment > 0);
        balances[msg.sender] = 0;
        msg.sender.transfer(payment);
        Withdraw(msg.sender, payment);
    }

    function funding() public view returns (bool) {
        Sale storage sale = sales[era];
        return now >= sale.startTime && now <= sale.endTime;
    }

    modifier whenFunding() {
        require(funding());
        _;
    }

    modifier whenNotFunding() {
        require(!funding());
        _;
    }

    function updateWallets(address _fund, address _fees) whenNotFunding onlyOwner public {
        wallets = Wallets(_fund, _fees);
        NewWallets(_fund, _fees);
    }

    function updateFees(uint _fund, uint _reward, uint _divisor) whenNotFunding onlyOwner public {
        require(_divisor > _fund && _divisor > _reward);
        fees = Fees(_fund, _reward, _divisor);
        NewFees(_fund, _reward, _divisor);
    }

    function addSale(uint _startTime, uint _endTime, uint _minPurchase) whenNotFunding onlyOwner public {
        require(_startTime >= now && _endTime >= _startTime);
        era = era.add(1);
        sales[era] = Sale(_startTime, _endTime, _minPurchase, 0);
        NewSale(era, _startTime, _endTime, _minPurchase);
    }
}
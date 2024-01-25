pragma solidity ^0.8.7;




/*
 🦋 PsycheArt - algorithm art butterflies.
*/

contract PsycheArt is ERC721Enumerable, Ownable {
    using Address for address;
    // consts define
    uint256 private constant SEX_FEMALE = 1;
    uint256 private constant SEX_MALE = 2;
    uint256 private constant SEX_BOTH = 3;
    
    uint256 private constant DATA_GEN = 0;
    uint256 private constant DATA_SEX = 1;
    uint256 private constant DATA_BREED_COUNT = 2;
    
    // 888 butterflies of 1st generation 
    uint256 private constant _maxSupply1stGen = 888;
    
    // max count per wallet addr.
    uint256 private constant _addressMaxMint = 5;
    
    // price will be
    uint256 private constant _price = 0.09 ether; 
    
    // breed price
    uint256 private constant _breedPrice = 0.02 ether;
    
    // token counter
    uint256 public nextTokenId = 1;
    
    // time
    uint256 public lastBreedTime;
    
    // ending time 12 hours
    uint256 private constant BREED_ENDING_TIME = 12 * 60 * 60;

    // sale time 
    uint256 public publicTime;
    
    // breed bonus value
    uint256 public currentBonus;

    // stored generation 5st tokenIds
    uint256[] private _tokensOf5thGen;

    // bred bonus records
    uint256[] private _bredBonusValues;

    // wallet
    address private walletAddr = 0xFdCEce98151bAd94001788E0b023201d0A33eDd7;
    
    // _lastBreedAddress 
    address[10] private _lastBreedAddress;

    // bred bonus records
    address[] private _bredBonusAddrs;
    
    // wallet adopt count
    mapping(address => uint256) private _addressAdopted;

    // white list
    mapping(address => uint256) private _whiteList;
    
    // butterflies generation info
    mapping(uint256 => uint256) private _butterfliesInfo;
    
    // butterflies images stored on ipfs
    string private _ipfsImageBaseURI;

    bool private _whiteListStarted;
    bool public revealed;

    event BreedEvent(address owner, uint256 childToken, uint256 info, uint256 bonus, bool feeback);
    event BonusEvent(uint256 eachBonus);
    event MintEvent(uint256 nextTokenId);

    constructor() ERC721("Psyche.Art", "PSY") {
    }

    function setWhiteListStarted(bool _isActive) external onlyOwner{
        _whiteListStarted = _isActive;
    }

    function whiteListStarted() public view returns(bool) {
        return _whiteListStarted;
    }

    function addToAllowList(address[] calldata addresses, uint256[] calldata counts) external onlyOwner {
        require(addresses.length == counts.length);

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0));
            _whiteList[addresses[i]] += counts[i];
        }
    }

    function getAllowListCount(address addr) external view returns (uint256) {
        return _whiteList[addr];
    }

    function removeFromAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0));
            _whiteList[addresses[i]] = 0;
        }
    }

    function adoptWhitelist(uint256 quantity) external payable {
        require(_whiteListStarted);
        require(!msg.sender.isContract(), 'contract not allowed');
        uint256 supply = nextTokenId;
        require(quantity > 0 && supply + quantity - 1 <= _maxSupply1stGen);
        require(_whiteList[msg.sender] > 0 && quantity <= _whiteList[msg.sender]);
        require(quantity * _price <= msg.value,'Inconsistent eth sent');
        
        // deposite 20% of minting price to contract for bonus.
        // 10% for startup, 10% for the continue adding.
        currentBonus += msg.value / 10;
        payable(walletAddr).transfer(msg.value * 4 / 5);

        for (uint256 i; i < quantity; i++) {
            _safeMint(msg.sender, supply + i);
            _generateInfo(supply + i, 1);
        }
        nextTokenId += quantity;
        _whiteList[msg.sender] -= quantity;

        if (nextTokenId > _maxSupply1stGen) {
            revealed = true;
        }
        emit MintEvent(nextTokenId);
    }

    function adopt(uint256 quantity) external payable {
        require(publicTime > 0 && block.timestamp >= publicTime);
        require(!msg.sender.isContract(), 'contract not allowed');
        uint256 supply = nextTokenId;
        require(quantity > 0 && supply + quantity - 1 <= _maxSupply1stGen);
        require(_addressAdopted[msg.sender] + quantity <= _addressMaxMint);
        require(quantity * _price <= msg.value,'Inconsistent eth sent');

        _addressAdopted[msg.sender] += quantity;
        
        // deposite 20% of minting price to contract for bonus.
        // 10% for startup, 10% for the continue adding.
        currentBonus += msg.value / 10;
        payable(walletAddr).transfer(msg.value * 4 / 5);

        for (uint256 i; i < quantity; i++) {
            _safeMint(msg.sender, supply + i);
            _generateInfo(supply + i, 1);
        }
        nextTokenId += quantity;
        
        if (nextTokenId > _maxSupply1stGen) {
            revealed = true;
        }
        emit MintEvent(nextTokenId);
    }
    
    function breed(uint256 tokenId1, uint256 tokenId2) external payable {
        require(publicTime > 0 && block.timestamp >= publicTime);
        require(revealed, "Not revealed");
        require(lastBreedTime <= 0 || block.timestamp - lastBreedTime < BREED_ENDING_TIME);
        require(!msg.sender.isContract());
        require(ownerOf(tokenId1) == address(msg.sender) && ownerOf(tokenId2) == address(msg.sender));
        require(_breedPrice <= msg.value, 'Inconsistent eth sent');
        
        uint256 parentInfo1 = _butterfliesInfo[tokenId1];
        uint256 parentInfo2 = _butterfliesInfo[tokenId2];
        
        // require breed state, make sure the parent can breed
        uint256 parentBreedcount1 = uint8a32.get(parentInfo1, DATA_BREED_COUNT);
        require(parentBreedcount1 > 0, 'Parent1 cannot breed');
        
        uint256 parentBreedcount2 = uint8a32.get(parentInfo2, DATA_BREED_COUNT);
        require(parentBreedcount2 > 0, 'Parent2 cannot breed');
        
        require(uint8a32.get(parentInfo1, DATA_SEX) != uint8a32.get(parentInfo2, DATA_SEX), 'Gender dismatch');
        
        uint256 parentGen1 = uint8a32.get(parentInfo1, DATA_GEN);
        uint256 parentGen2 = uint8a32.get(parentInfo2, DATA_GEN);
        // the next generation depends on the older generation
        uint256 childGeneration = parentGen1 < parentGen2 ? parentGen1 + 1: parentGen2 + 1;

        _butterfliesInfo[tokenId1] = uint8a32.set(parentInfo1, DATA_BREED_COUNT, parentBreedcount1 - 1);
        _butterfliesInfo[tokenId2] = uint8a32.set(parentInfo2, DATA_BREED_COUNT, parentBreedcount2 - 1);
        
        // generate child info
        (uint256 sex, uint256 seed) = _generateInfo(nextTokenId, childGeneration);
        // mint the child
        _safeMint(msg.sender, nextTokenId);
        
        // add breed fee
        currentBonus += _breedPrice;

        // update nextToken
        nextTokenId ++;
        
        // update breed record
        address sender = address(msg.sender);
        uint256 src;
        for (uint256 i; i < 10; i ++) {
            if (_lastBreedAddress[i] == sender) {
                src = i;
                break;
            }
        }
        for (uint256 j = src; j < 9; j ++) {
            _lastBreedAddress[j] = _lastBreedAddress[j + 1];
        }
        _lastBreedAddress[9] = sender;
        lastBreedTime = block.timestamp;

        // holding 5st generation has 50% chance to get breed fee back
        bool feeback;
        if (random(seed, 0) % 2 == 0) {
            uint256 len = _tokensOf5thGen.length;
            if (len > 0) {
                for (uint256 m; m < len; m++) {
                    address holder = ownerOf(_tokensOf5thGen[m]);
                    if (holder == sender) { 
                        payable(sender).transfer(_breedPrice);
                        currentBonus -= _breedPrice;
                        feeback = true;
                        break;
                    }
                }
            }
        }
        // 5st generation add to list
        if (childGeneration > 4) {
            _tokensOf5thGen.push(childGeneration);
        }

        // address who bred Androgynous one may get the 50% of current bonus value
        if (sex == SEX_BOTH && currentBonus <= address(this).balance) {
            uint256 bredBonus = currentBonus / 2;
            currentBonus = currentBonus - bredBonus;
            
            payable(sender).transfer(bredBonus);

            // add 1eth to current bonus when 500 increased
            fillBonusEvery500();
            // emit event
            emit BreedEvent(msg.sender, nextTokenId-1, _butterfliesInfo[nextTokenId-1], bredBonus, feeback);

            // store bonus records
            uint256 cnt = _bredBonusAddrs.length;
            for (uint256 n; n < cnt; n ++) {
                if (_bredBonusAddrs[n] == sender){
                    _bredBonusValues[n] += bredBonus;
                    return;
                }
            }
            _bredBonusAddrs.push(sender);
            _bredBonusValues.push(bredBonus);
            return;
        }
        // add 1eth to current bonus when 500 increased
        fillBonusEvery500();
        // emit event
        emit BreedEvent(msg.sender, nextTokenId-1, _butterfliesInfo[nextTokenId-1], 0, feeback);
    }

    function fillBonusEvery500() internal {
        // add 1eth to current bonus when 500 increased
        if ((nextTokenId - _maxSupply1stGen) % 500 == 1) {
            if (address(this).balance > currentBonus + 1 ether) {
                currentBonus += 1 ether;
            } else {
                currentBonus = address(this).balance;
            }
        }
    }
    
    // distribute bonus to the last 10 addresses.
    function distributeBonus() external onlyOwner {
        require(lastBreedTime > 0 && block.timestamp - lastBreedTime >= BREED_ENDING_TIME, 'still breeding');

        uint256 breedAddressCount;
        for (uint256 i = 0; i < 10; i ++) {
            if (_lastBreedAddress[i] != address(0)) {
                breedAddressCount ++;
            }
        }

        if (currentBonus > address(this).balance) {
            currentBonus = address(this).balance;
        }
        // cut to equal pieces
        uint256 eachBonus = currentBonus / breedAddressCount;
        for (uint256 i = 0; i < 10; i ++) {
            if (_lastBreedAddress[i] != address(0)) {
                payable(_lastBreedAddress[i]).transfer(eachBonus);
            }
        }
        currentBonus = 0;
        // if balance left , return to creator.
        if (address(this).balance > 0) {
            payable(walletAddr).transfer(address(this).balance);
        }
        
        // emit event
        emit BonusEvent(eachBonus);
    }
   
    function getTokensOfOwner(address addr) external view returns (uint256[] memory) {
        uint256 amount = balanceOf(addr);
        uint256[] memory tokens = new uint256[](amount);
        for (uint256 i; i < amount; i ++) {
            tokens[i] = tokenOfOwnerByIndex(addr, i);
        }
        return tokens;
    }

    function getBredRecords() external view returns(address[] memory, uint256[] memory, address[10] memory) {
        return (_bredBonusAddrs, _bredBonusValues, _lastBreedAddress);
    }
    
    function setPublicTime(uint256 _publicTime) external onlyOwner { 
        publicTime = _publicTime;
    }

    function saleStarted() external view returns(bool) {
        return publicTime > 0 && block.timestamp >= publicTime;
    }

    function setRevealed() external onlyOwner {
        revealed = true;
    }

    function getBreedStatus() external view returns(uint256) {
        if (!revealed) {
            return 1;
        }
        if (lastBreedTime > 0 && block.timestamp - lastBreedTime >= BREED_ENDING_TIME) {
            return 2;
        }
        return 0;
    }
    
    function setImageBaseURI(string calldata baseUri) external onlyOwner {
        _ipfsImageBaseURI = baseUri;
    }
    
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        require(_exists(tokenId));
        string memory json;
        if (!revealed) {
            json = Base64.encode(bytes(string(abi.encodePacked('{"name": "ButterFly #', Base64.toString(tokenId), description, _ipfsImageBaseURI, '"}'))));
        } else {
            uint256 butterflyInfo = _butterfliesInfo[tokenId];
            uint256 sex = uint8a32.get(butterflyInfo, DATA_SEX);
            uint256 generation = uint8a32.get(butterflyInfo, DATA_GEN);
            uint256 breedcount = uint8a32.get(butterflyInfo, DATA_BREED_COUNT);

            string memory szTokenId = Base64.toString(tokenId);
            string memory szGender;
            if (sex == SEX_FEMALE) {
                szGender = "Female";
            } else if (sex == SEX_MALE) {
                szGender = "Male";
            } else {
                szGender = "Androgynous";
            }
            
            uint256 breedMaxcount;
            // the max generation and Androgynous butterfly cannot breed next child
            if (sex != SEX_BOTH) {
                if (generation < 4) {
                    breedMaxcount = 4 - generation;
                } else if (generation == 4) {
                    breedMaxcount = 1;
                }
            }
            
            string memory breedstate = string(abi.encodePacked(Base64.toString(breedcount), "/", Base64.toString(breedMaxcount)));
            string memory attributes = string(abi.encodePacked('"attributes": [{"trait_type":"Gender","value": "', szGender,'"}, {"trait_type":"Breedable","value": "', breedcount > 0 ? "True" : "False",'"}, {"trait_type":"BreedCount","value": "', breedstate,'"}, {"trait_type":"Generation","value": "', Base64.toString(generation),'"}]'));
            json = Base64.encode(bytes(string(abi.encodePacked('{"name": "', sex == SEX_BOTH ? 'Ghost #' : 'ButterFly #', szTokenId, description, _ipfsImageBaseURI, szTokenId, sex == SEX_BOTH ? '10.png",' : '00.png",', attributes, '}'))));
        }
        string memory output = string(abi.encodePacked('data:application/json;base64,', json));
        return output;
    }
    
    function random(uint256 seed1, uint256 seed2) internal view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed1, seed2)));
    }

    function _generateInfo(uint256 tokenId, uint256 generation) internal returns(uint256, uint256){
        //random sex
        uint256 rand = random(generation, tokenId);
        uint256 sex;
        if (generation <= 1) {
            if (rand % 2 == 0) {
                // 50% for female
                sex = SEX_FEMALE;
            } else {
                sex = SEX_MALE;
            }
        } else {
            // 0.5% for Androgynous
            if (rand % 1000 < 5) { 
                sex = SEX_BOTH;
            // 49.75% for female
            } else if (rand % 2 == 0) {
                sex = SEX_FEMALE;
            } else { 
                sex = SEX_MALE;
            }
        }
        
        uint256 info; // uint32 generation, uint32 sex, uint32 breedcount
        info = uint8a32.set(info, DATA_GEN, generation);
        info = uint8a32.set(info, DATA_SEX, sex);
        
        uint256 breedcount;
        // the max generation and Androgynous butterfly cannot breed next child
        if (sex != SEX_BOTH) {
            if (generation < 4) {
                breedcount = 4 - generation;
            } else if (generation == 4) {
                breedcount = 1;
            }
        }
        
        _butterfliesInfo[tokenId] = uint8a32.set(info, DATA_BREED_COUNT, breedcount);

        return (sex, rand);
    }
    
    function getButterflyInfo(uint256[] memory tokenId) external view returns(uint32[] memory) {
        uint256 count = tokenId.length;
        uint32[] memory infos = new uint32[](count);
        uint256 id;
        for (uint256 i; i < count; i++) {
            id = tokenId[i];
            require(_exists(id));
            infos[i] = uint32(_butterfliesInfo[id]);
        }
        return infos;
    }

    string private constant description = '", "description": "Psyche.Art is an algorithm art collection of 888 OG on-chain butterflies. All the metadata are stored on the smart contract and images are stored on IPFS.","image": "';
}

library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
    
    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

// uint8[32]
library uint8a32 { 
    uint256 constant bits = 8;
    uint256 constant elements = 32;
    uint256 constant range = 1 << bits;
    uint256 constant max = range - 1;

    // get value
    function get(uint256 srcValue, uint256 index) internal pure returns (uint256) {
        require(index < elements, 'idx oor');
        return ((srcValue >> (bits * index)) & (max));
    }
    
    // set value
    function set(uint256 srcValue, uint256 index, uint256 value) internal pure returns (uint256) {
        require(index < elements, 'idx oor');
        require(value < range, 'val oor');
        index *= bits;
        return (srcValue & ~(max << index)) | (value << index);
    }
}
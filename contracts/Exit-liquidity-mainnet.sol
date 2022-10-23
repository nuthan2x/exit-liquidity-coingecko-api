// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15 ;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./1inch-oracle.sol";

contract Exitliquidity is Ownable {
    

    enum Dealstatus { notforsale, forsale, cancelled, success }

    struct Tokeninfo {
        address token;
        //bool neworfill; true if new list, false if direct fill of order listed by others,can use status to determine .
        Dealstatus status;
        // address filler; // use events to show in frontend/ index with thegraph
        address[] tokensaccepted;
        uint _amount;
        uint expiration; 
    }
    mapping (address => Tokeninfo[]) public user;

    event ListedPositions(address indexed user, uint indexed positionindex, uint _amount, uint _expiration);
    event Filled(address indexed user, uint indexed positionindex,bool ethtransfer, uint price, uint timestamp);
    receive() external payable {}

    function withdrawETH(uint _ether) external onlyOwner {
        require(_ether <= address(this).balance,"not enough balance");
        payable(owner()).transfer(_ether);
    }

    // we collect 0.5% of token amount here as listing fee and transferred to owner directly;
    function marketOrder(address _token, uint _amount, address[] memory _tokensaccepted, uint expiration) external payable {
        require(IERC20(_token).balanceOf(msg.sender) >= _amount,"you dont have enough tokens");
        require(expiration >= block.timestamp + 86000,"increase expiration to alteast 1 day");
        
        Tokeninfo memory _tokeninfo = Tokeninfo( _token, Dealstatus.forsale,_tokensaccepted, _amount, expiration);
        user[msg.sender].push(_tokeninfo);
// first do the approval function in the frontend then, follow the this function call
        IERC20(_token).transferFrom(msg.sender,address(this), _amount ); // * 995 / 1000  if 0.5% platform fee   

        // IERC20(_token).transferFrom(msg.sender, payable(owner()), _amount * 5 / 1000); // 0.5% platform fee or transfer eth/stablecoins as fee
        // if you traansfer fee as eth/other erc20 token use priceoracle to get rate then do approval in frontend, then do ransferfrom call.    

        emit ListedPositions(msg.sender,((user[msg.sender]).length - 1),_amount, expiration);
    }
    
    // liquidity will be cleared with eth only (means token of that network => eth in ethereum nets, matic in polygon net(cange api getrequest acc to each network))
    function fillOrder(address _user, uint index, bool payinETH, address _desttoken)  external payable {
        Tokeninfo[] storage tokeninfos = user[_user];
        require(_istokensaccepted(tokeninfos[index].tokensaccepted,_desttoken),'the desttoken token will not be accepted by lister');
        
        OffchainOracle oracle_1inch = OffchainOracle(0x07D91f5fb9Bf7798734C3f606dB065549F6893bb); // for mainnet ethereum
        require(tokeninfos[index].status == Dealstatus.forsale,"either expired or paused");
        uint decimals = ERC20(tokeninfos[index].token).decimals() ;
        uint transfersto_emit;
        IERC20 srctoken = IERC20(tokeninfos[index].token);
        IERC20 desttoken = IERC20(_desttoken);

        if (payinETH){
            uint ethprice = oracle_1inch.getRateToEth(srctoken,true);
            uint ethtotransfer = tokeninfos[index]._amount / ethprice ;
            require((msg.sender).balance >= (ethtotransfer / (10 ** (36 - decimals))),'insufficient eth balance');
            require(msg.value >= (ethtotransfer / (10 ** (36 - decimals)))," transfer eth at updated price");
            transfersto_emit = ethtotransfer / (10 ** (36 - decimals));
            payable(_user).transfer(msg.value);
        }else {
// first do the approval function call in the frontend ,then follow this function call     
            uint getrate = oracle_1inch.getRate(srctoken, desttoken, true);
            uint desttokens_totransfer = tokeninfos[index]._amount * getrate ;
            IERC20(_desttoken).transferFrom(msg.sender, payable(_user), (desttokens_totransfer / (10 ** (36 - decimals))));

        }
        
        tokeninfos[index].status = Dealstatus.success;


        IERC20(tokeninfos[index].token).transfer(payable(msg.sender),tokeninfos[index]._amount);

        emit Filled(_user,index,payinETH,transfersto_emit,block.timestamp);
    }

    function pauseorder(uint index)  external  { // to pause that position 
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        require(tokeninfos[index].status != Dealstatus.success,"this position is liquidated");
        require(tokeninfos[index].status == Dealstatus.forsale,"this position is not currently listed for sale");
        tokeninfos[index].status = Dealstatus.notforsale;
    }

    function unpausePosition(uint index) external  {
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        require(tokeninfos[index].status != Dealstatus.success,"this position is liquidated");
        require(tokeninfos[index].status == Dealstatus.notforsale,"this position is not currently paused");
        tokeninfos[index].status = Dealstatus.forsale;     
    }

    function increaseExpiration(uint index, uint newexpiration) external  {
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        require(tokeninfos[index].status != Dealstatus.notforsale,"this position is not currently listed for sale");
        require(tokeninfos[index].status != Dealstatus.success,"this position is liquidated");
        tokeninfos[index].expiration = tokeninfos[index].expiration  +  newexpiration;
    }

    function cancelorder(uint index)  external  { // to cancel that position 
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        require(tokeninfos[index].status != Dealstatus.success,"this position is liquidated");
        tokeninfos[index].status = Dealstatus.cancelled;
        IERC20(tokeninfos[index].token).transfer(payable(msg.sender),tokeninfos[index]._amount);

    }

    function addacceptedtokens(uint index, address[] memory new_srctokens) external {
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        address[] storage _tokensaccepted = tokeninfos[index].tokensaccepted;

        for (uint i = 0; i < new_srctokens.length; i++) {
            if(new_srctokens[i] != address(0)) {
               _tokensaccepted.push(new_srctokens[i]); 
            } 
        }
    }

    function removeacceptedtokens(uint index, address[] memory _srctokens) external {
        Tokeninfo[] storage tokeninfos = user[msg.sender];
        address[] storage _tokensaccepted = tokeninfos[index].tokensaccepted;

        for (uint i = 0; i < _tokensaccepted.length; i++) {

            for (uint j = 0; j < _srctokens.length; j++) {
                if(_tokensaccepted[i] == _srctokens[j]) {
                   _tokensaccepted[i] = address(0); 
                }             
            }
        }
    }

    // returns a bool = true if the input token is one of the tokens the lister accepts
    function _istokensaccepted(address[] memory _tokensaccepted,address _desttoken) public pure returns (bool) {
        bool accepted;
        for (uint i = 0; i < _tokensaccepted.length; i++) {
            if (_tokensaccepted[i] == _desttoken) {
                if(_tokensaccepted[i] != address(0)) {
                   accepted = true;  
                } 
                break;
            }
        }
        return accepted;
    }
    
}

// const demouser = '0x78351284f83A52b726aeEe6C2ceBBe656124434c';

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17 ;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Chainlink-APInew.sol";

contract Exitliquidity is Ownable {
    

    enum Dealstatus { notforsale, forsale, cancelled, success }

    struct Tokeninfo {
        address token;
        //bool neworfill; true if new list, false if direct fill of order listed by others,can use status to determine .
        Dealstatus status;
        // address filler; // use events to show in frontend/ index with thegraph
        uint _amount;
        uint expiration; 
    }
    mapping (address => Tokeninfo[]) public user;

    event ListedPositions(address indexed user, uint indexed positionindex, uint _amount, uint _expiration);
    event Filled(address indexed user, uint indexed positionindex, uint price, uint timestamp);
    receive() external payable {}

    function withdrawETH(uint _ether) external onlyOwner {
        require(_ether <= address(this).balance,"not enough balance");
        payable(owner()).transfer(_ether);
    }


    // we collect 0.5% of token amount here as listing fee and transferred to owner directly;
    function marketOrder(address _token, uint _amount, uint expiration) external payable {
        require(IERC20(_token).balanceOf(msg.sender) >= _amount,"you dont have enough tokens");
        require(expiration >= block.timestamp + 86000,"increase expiration to alteast 1 day");
        
        Tokeninfo memory _tokeninfo = Tokeninfo( _token, Dealstatus.forsale, _amount, expiration);
        user[msg.sender].push(_tokeninfo);
        // IERC20(_token).approve(msg.sender,_amount);
        IERC20(_token).transferFrom(msg.sender,address(this), _amount ); // * 995 / 1000  if 0.5% platform fee   

        // IERC20(_token).transferFrom(msg.sender, payable(owner()), _amount * 5 / 1000); // 0.5% platform fee     

        emit ListedPositions(msg.sender,((user[msg.sender]).length - 1),_amount, expiration);
    }
    
    // liquidity will be cleared with eth only (means token of that network => eth in ethereum nets, matic in polygon net(cange api getrequest acc to each network))
    function fillOrder(address _user, uint index)  external {
        Tokeninfo[] storage tokeninfos = user[_user];
        APIConsumer  getprice = APIConsumer(0x7d622629016Ae51F3719DF4741E5B63649445B9A);

        require(tokeninfos[index].status == Dealstatus.forsale,"either expired or paused");
        getprice.requestVolumeData(tokeninfos[index].token);
        uint priceineth = getprice.volume();
        tokeninfos[index].status = Dealstatus.success;

        uint ethtotransfer = tokeninfos[index]._amount * 1e18/ priceineth;
        payable(_user).transfer(ethtotransfer);

        IERC20(tokeninfos[index].token).transfer(payable(msg.sender),tokeninfos[index]._amount);

        emit Filled(_user,index,priceineth,block.timestamp);
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
    
}

// 0x22e5D45BB40ad3844Fa062135C5010429B1920a7 2pm thurs
// const user = '0x78351284f83A52b726aeEe6C2ceBBe656124434c';

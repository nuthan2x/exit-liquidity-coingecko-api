// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./confirmedower.sol";

contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

contract APIConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 public volume;
    bytes32 private jobId;
    uint256 private fee;

    event RequestVolume(bytes32 indexed requestId, uint256 volume);

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB); //--goerli
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7); //--goerli
        jobId = 'ca98366cc7314957b8c012c72f05aeeb';
        fee = (1 * LINK_DIVISIBILITY) / 10; 
    }


    function requestVolumeData(address _contract) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        string memory requrl = appendString(
            'https://api.coingecko.com/api/v3/simple/token_price/ethereum?contract_addresses=',
            toString(abi.encodePacked(_contract)),
            '&vs_currencies=eth'
            ); 
        req.add('get', requrl);

        string memory path = string(abi.encodePacked(toString(abi.encodePacked(_contract)),",eth"));

        req.add('path', path); 

        int256 timesAmount = 10**18;
        req.addInt('times', timesAmount);

        return sendChainlinkRequest(req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId) {
        emit RequestVolume(_requestId, _volume);
        volume = _volume;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

        function appendString(string memory _a, string memory _b, string memory _c) public pure returns (string memory)  {
        return string(abi.encodePacked(_a, _b, _c));
    }

    function toString(bytes memory data) public pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}

// deployed -- goerli address 0xA2cdB83678d1f6A40627C53F4433a615C41e4cB2 in usd , 0x7d622629016Ae51F3719DF4741E5B63649445B9A in eth  

// link goerli  0x326C977E6efc84E512bB9C30f76E30c160eD06FB     // dai 0x6B175474E89094C44Da98b954EedeAC495271d0F 
// oracle 0xCC79157eb46F5624204f47AB42b3906cAA40eaB7
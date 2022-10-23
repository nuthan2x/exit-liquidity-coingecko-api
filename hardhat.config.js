require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  etherscan: {
    apiKey: "B9SEZ4K5MAMTI9FEPDQRBIQP9GW4WN5GFG",
  },
  networks : {
    goerli : {
      url : "https://rpc.ankr.com/eth_goerli",
      accounts : ["059bcd5d85e0f99074148e694668d244d90b98bc50bc1c8d4f26785741a5e4c9"],
    }
  }

};

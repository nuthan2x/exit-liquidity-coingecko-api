import { ethers } from 'ethers';
import React,{useState, useEffect} from 'react'
import {
    useAccount ,
    useSigner,
    useContract,
  } from 'wagmi';
import ABI from "../ABI/Exitliquidity.json"
import IERC20_ABI from "../ABI/IERC20.json"
import Web3 from 'web3';


export const Marketplace = () => {
    const { address, isConnecting, isDisconnected } = useAccount()
    const { data: signer, isError, isLoading } = useSigner();

    const [input, setinput] = useState({token : "", amount : "", expiry :{ hours :'',days : ''}});
    const [approved, setapproved] = useState(false);

    

    
    const approve = async () => {
      if(input.token && input.amount) {

        try {
          const erc20Contract = new ethers.Contract(input.token,IERC20_ABI,signer);
          const decimal_multipliedamount = await erc20Contract.decimals();
          const DECIMAL = ethers.BigNumber.from(10).pow(decimal_multipliedamount)
          const totalamount =  ethers.BigNumber.from(input.amount).mul(DECIMAL);
          const txn = await erc20Contract.approve(input.token, totalamount);
          console.log('txn: ', `https://goerli.etherscan.io/tx/${txn.hash}`);
          let receipt = await txn.wait();
          setapproved(prev => !prev);

        } catch(error) {
          console.log(error.message);
        }

      }else{
        alert("please select the erc20 token/token count to list")
      }  
    }

    const listorder = async () => {
      if(input.token && (input.amount && (input.expiry.hours || input.expiry.days))){

        const erc20Contract = new ethers.Contract(input.token,IERC20_ABI,signer);
        const decimal_multipliedamount = await erc20Contract.decimals();
        const DECIMAL = ethers.BigNumber.from(10).pow(decimal_multipliedamount)
        const totalamount =  ethers.BigNumber.from(input.amount).mul(DECIMAL);
        
        const CONTRACT_ADDRESS = '0x22e5D45BB40ad3844Fa062135C5010429B1920a7';
        const Contract = new ethers.Contract(CONTRACT_ADDRESS,ABI,signer)
        console.log('contract: ', Contract);

        let expiration = ((input.expiry.hours * 24) + (input.expiry.hours)) * 3600  // in seconds
        let expiry_timestamp = Math.floor( Date.now() / 1000) + expiration ; 
        
        try {
          const txn = await Contract.marketOrder(input.token, totalamount,expiry_timestamp);
          console.log('txn: ', `https://goerli.etherscan.io/tx/${txn.hash}`);
          let receipt = await txn.wait()

        } catch (error) {
          console.log(error.message);
        }
      }
    }



  return (
    <div className="marketplacecontainer">
      <div className="inputs">
          <form action="">
            <label htmlFor="">token</label>
            <input type="text" placeholder='erc20 token address' onChange={e => setinput(prev => {return{...prev,token: Web3.utils.toChecksumAddress(e.target.value)}})}/>
            <label htmlFor="">amount</label>
            <input type="text" placeholder='no. of tokens to list' onChange={e => setinput(prev => {return{...prev,amount: e.target.value}})}/>
            <label htmlFor="">expiry</label>
            <input type="text" placeholder='days' onChange={e => setinput(prev => {return{...prev,expiry :{ hours : prev.expiry.hours, days :  e.target.value}}})}/>
            <input type="text" placeholder='hours' onChange={e => setinput(prev => {return{...prev,expiry :{ days :prev.expiry.days,  hours :  e.target.value}}})}/>
          </form>
      </div>
      <div className="buttons">
        <button className="approve" onClick={approve}>
          Approve
        </button>
        <button className="list" onClick={listorder}>
          list
        </button>
      </div>
    </div>
  )
}
export default Marketplace
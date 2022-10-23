import '../App.css';
import '@rainbow-me/rainbowkit/styles.css';
import {
  getDefaultWallets,
  RainbowKitProvider,
} from '@rainbow-me/rainbowkit';
import {
  chain,
  configureChains,
  createClient,
  WagmiConfig,
  useContractEvent,
  useContractRead ,
  useSigner,
  useContract,
} from 'wagmi';

import { alchemyProvider } from 'wagmi/providers/alchemy';
import { publicProvider } from 'wagmi/providers/public';
import { useEffect, useState } from 'react';
import { ConnectButton ,lightTheme} from '@rainbow-me/rainbowkit';
import { ethers } from 'ethers';
import Marketplace from './listorder';
import FilterRowDemo from './fillorder.tsx';

const { chains, provider } = configureChains(
  [chain.goerli],
  [
    alchemyProvider({ apiKey: 'kBCMGtSUEZ3Yrkg6WRv4Z9B5s7-_VwxX' }),
    publicProvider()
  ]
);

const { connectors } = getDefaultWallets({
  appName: 'My RainbowKit App',
  chains
});

const wagmiClient = createClient({
  autoConnect: false,
  connectors,
  provider
})





function App() {


  return (
    <WagmiConfig client={wagmiClient}>
      <RainbowKitProvider chains={chains} modalSize="compact" theme={{
      lightMode: lightTheme(),
      // darkMode: darkTheme(),
    }} initialChain={chain.goerli}>
        
      <div className="App">
        <header className="App-header">
        
            <ConnectButton showBalance={false} 
              accountStatus={{
                  smallScreen: 'address',
                  largeScreen: 'full',
                }}
            />
        </header>
        
        <div className="App-body">
              <Marketplace />
              <FilterRowDemo />
        </div>
       </div>
,
      </RainbowKitProvider>
    </WagmiConfig>
    
  );
}

export default App;

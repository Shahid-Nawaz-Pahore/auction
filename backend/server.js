const express = require('express');
const { ethers } = require('ethers');
const dotenv = require('dotenv');

dotenv.config(); // Load environment variables from .env

const app = express();
app.use(express.json()); // Middleware to parse JSON

const PORT = 3000;

// Initialize Ethers.js with the Polygon testnet (Mumbai) RPC URL
const provider = new ethers.providers.JsonRpcProvider(process.env.POLYGON_RPC_URL);

// Load your wallet using your private key
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Import your contract's ABI (ensure this file is correctly exported)
const contractABI = require('./abi.js');
const contractAddress = process.env.CONTRACT_ADDRESS;

// Create an instance of your auction contract
const auctionContract = new ethers.Contract(contractAddress, contractABI, wallet);

// Sample route to check if server is running
app.get('/', (req, res) => {
    res.send('Auction API is running');
});

// Create a new auction
app.post('/create-auction', async (req, res) => {
    try {
        const { auctionType, startPrice, endTime, priceDecrement } = req.body;

        if (typeof auctionType !== 'number' || typeof startPrice !== 'number' || typeof endTime !== 'number' || typeof priceDecrement !== 'number') {
            return res.status(400).json({ error: 'Invalid data types provided.' });
        }

        const currentTime = Math.floor(Date.now() / 1000); // Current Unix timestamp
        if (endTime <= currentTime) {
            return res.status(400).json({ error: 'End time must be in the future.' });
        }

        // Get current gas price and fee parameters
        const gasPrice = await provider.getGasPrice();
        const maxPriorityFeePerGas = await provider.send('eth_maxPriorityFeePerGas', []); // Fetch recommended priority fee

        // Set transaction gas fees
        const newMaxFeePerGas = gasPrice.mul(2); // Set maxFeePerGas to 2x current gas price
        const newMaxPriorityFeePerGas = ethers.BigNumber.from(maxPriorityFeePerGas); // Convert the priority fee to a BigNumber

        // Create auction transaction
        const tx = await auctionContract.createAuction(auctionType, startPrice, endTime, priceDecrement, {
            gasLimit: 1000000, // Adjust as needed
            maxFeePerGas: newMaxFeePerGas,
            maxPriorityFeePerGas: newMaxPriorityFeePerGas,
        });

        await tx.wait(); // Wait for transaction to be mined
        res.status(200).json({ message: 'Auction created successfully', transactionHash: tx.hash });
    } catch (error) {
        console.error('Error creating auction:', error);
        res.status(500).json({ error: 'Error creating auction', details: error.message });
    }
});




// Start server
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});

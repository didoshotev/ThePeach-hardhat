require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require('hardhat-deploy');
require("hardhat-gas-reporter"); // ADD REPORT_GAS=true in .env to work
require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */


const accounts = [
	{ privateKey: process.env.WALLET_PRIVATE_KEY, balance: "10000000000000000000000" },
	{ privateKey: process.env.TEAM_WALLET_PRIVATE_ADDRESS, balance: "20000000000000000000000" },
	{ privateKey: process.env.TREASURY_PRIVATE_KEY, balance: "30000000000000000000000" },
];

const INFURA_URL = `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`;

module.exports = {
	solidity: {
		compilers: [
			{
				version: "0.5.0",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200
					}
				},
			},
			{
				version: "0.6.12",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200
					}
				},
			},
			{
				version: "0.8.4",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200
					}
				},
			},
		],
	},
	defaultNetwork: "hardhat",
	networks: {
		hardhat: {
			chainId: 43114,
			gasPrice: 225000000000,
			throwOnTransactionFailures: true,
			loggingEnabled: false,

			forking: {
				url: "https://api.avax.network/ext/bc/C/rpc",
				enabled: true,
				blockNumber: 8528605
			},
		},
		rinkeby: {
			url: INFURA_URL,
			accounts: [
				process.env.WALLET_PRIVATE_KEY,
				process.env.TEAM_WALLET_PRIVATE_ADDRESS,
				process.env.TREASURY_PRIVATE_KEY
			],
			live: true,
			saveDeployments: true,
			tags: ["rinkeby-test-network"]
		}
	},

	namedAccounts: {
		deployer: {
			default: process.env.WALLET_ADDRESS,
			1: 0,
			4: 0,
			43114: process.env.WALLET_ADDRESS
		},
		walletAccount: {
			default: process.env.TEAM_WALLET_ADDRESS,
			1: 1,
			4: 1,
			43114: process.env.TEAM_WALLET_ADDRESS
		},
		treasury: {
			default: process.env.TREASURY_ADDRESS,
			1: 2,
			4: 2,
			43114: process.env.TREASURY_ADDRESS
		}
	},

	paths: {
		sources: "./contracts",
		tests: "./test",
		cache: "./cache",
		artifacts: "./artifacts"
	},
	mocha: {
		timeout: "40000"
	},

	gasReporter: {
		currency: 'USD',
		gasPrice: 21,
		enabled: (process.env.REPORT_GAS) ? true : false
	  }
}

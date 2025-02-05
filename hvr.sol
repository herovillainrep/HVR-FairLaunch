/*────────────────────────────┐
Developed by Coinsult                       
 _____     _             _ _   
|     |___|_|___ ___ _ _| | |_ 
|   --| . | |   |_ -| | | |  _|
|_____|___|_|_|_|___|___|_|_|  
                               
tg: @coinsult_tg
──────────────────────────────┘

SPDX-License-Identifier: MIT */

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract HVR is ERC20, Ownable(msg.sender) {
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping (address => bool) public isExcludedFromEnable;
    bool    public  tradingEnabled;

    error TradingNotEnabled();
    error TradingAlreadyEnabled();

    event TradingEnabled();
    event ExcludedFromEnable(address indexed account, bool isExcluded);

    constructor () ERC20("Hero Villain Republic", "HVR") {
        address router;
        address pinkLock;
        
        if (block.chainid == 56) {
            router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            pinkLock = 0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE; 
        } else if (block.chainid == 97) {
            router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
            pinkLock = 0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5;
        } else if (block.chainid == 1 || block.chainid == 5) {
            router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            pinkLock = 0x71B5759d73262FBb223956913ecF4ecC51057641;
        } else {
            revert();
        }

        uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        isExcludedFromEnable[owner()] = true;
        isExcludedFromEnable[address(0xdead)] = true;
        isExcludedFromEnable[address(this)] = true;
        isExcludedFromEnable[pinkLock] = true;

        maxTransactionLimitEnabled = true;

        _isExcludedFromMaxTxLimit[owner()] = true;
        _isExcludedFromMaxTxLimit[address(this)] = true;
        _isExcludedFromMaxTxLimit[address(0xdead)] = true;
        _isExcludedFromMaxTxLimit[pinkLock] = true;

        super._update(address(0), owner(), 10e9 * (10 ** decimals()));

        maxTransactionAmountBuy     = totalSupply() * 5 / 1000;
        maxTransactionAmountSell    = totalSupply() * 5 / 1000;
    }

    receive() external payable {}

    function _update(address from, address to, uint256 value) internal override {
        bool isExcluded = isExcludedFromEnable[from] || isExcludedFromEnable[to];

        if (!isExcluded && !tradingEnabled) {
            revert TradingNotEnabled();
        }

        if (maxTransactionLimitEnabled) 
        {
            if ((from == uniswapV2Pair || to == uniswapV2Pair) &&
                !_isExcludedFromMaxTxLimit[from] && 
                !_isExcludedFromMaxTxLimit[to]
            ) {
                if (from == uniswapV2Pair) {
                    require(
                        value <= maxTransactionAmountBuy,  
                        "AntiWhale: Transfer amount exceeds the maxTransactionAmount"
                    );
                } else {
                    require(
                        value <= maxTransactionAmountSell, 
                        "AntiWhale: Transfer amount exceeds the maxTransactionAmount"
                    );
                }
            }
        }

        super._update(from, to, value);
    }

    function enableTrading() external onlyOwner {
        if (tradingEnabled) {
            revert TradingAlreadyEnabled();
        }

        tradingEnabled = true;

        emit TradingEnabled();
    }

    function excludeFromEnable(address account, bool excluded) external onlyOwner{
        isExcludedFromEnable[account] = excluded;

        emit ExcludedFromEnable(account, excluded);
    }

    function recoverStuckTokens(address token) external onlyOwner {
        if (token == address(0x0)) {
            payable(msg.sender).transfer(address(this).balance);
            return;
        }

        IERC20 ERC20token = IERC20(token);
        uint256 balance = ERC20token.balanceOf(address(this));
        ERC20token.transfer(msg.sender, balance);
    }

    mapping(address => bool) private _isExcludedFromMaxTxLimit;
    bool    public  maxTransactionLimitEnabled;
    uint256 public  maxTransactionAmountBuy;
    uint256 public  maxTransactionAmountSell;

    event ExcludedFromMaxTransactionLimit(address indexed account, bool isExcluded);
    event MaxTransactionLimitStateChanged(bool maxTransactionLimit);
    event MaxTransactionLimitAmountChanged(uint256 maxTransactionAmountBuy, uint256 maxTransactionAmountSell);

    function setEnableMaxTransactionLimit(bool enable) external onlyOwner {
        require(enable != maxTransactionLimitEnabled, "Max transaction limit is already set to that state");
        maxTransactionLimitEnabled = enable;

        emit MaxTransactionLimitStateChanged(maxTransactionLimitEnabled);
    }

    function setMaxTransactionAmounts(uint256 _maxTransactionAmountBuy, uint256 _maxTransactionAmountSell) external onlyOwner {
        require(
            _maxTransactionAmountBuy  >= (totalSupply() / (10 ** decimals())) / 1_000 && 
            _maxTransactionAmountSell >= (totalSupply() / (10 ** decimals())) / 1_000, 
            "Max Transaction limis cannot be lower than 0.1% of total supply"
        ); 
        maxTransactionAmountBuy  = _maxTransactionAmountBuy  * (10 ** decimals());
        maxTransactionAmountSell = _maxTransactionAmountSell * (10 ** decimals());

        emit MaxTransactionLimitAmountChanged(maxTransactionAmountBuy, maxTransactionAmountSell);
    }

    function excludeFromMaxTransactionLimit(address account, bool exclude) external onlyOwner {
        require( _isExcludedFromMaxTxLimit[account] != exclude, "Account is already set to that state");
        require(account != address(this), "Can't set this address.");

        _isExcludedFromMaxTxLimit[account] = exclude;

        emit ExcludedFromMaxTransactionLimit(account, exclude);
    }

    function isExcludedFromMaxTransaction(address account) public view returns(bool) {
        return _isExcludedFromMaxTxLimit[account];
    }
}
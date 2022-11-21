// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./WETH.sol";
import "./SafeMath.sol";

contract DepositContract {
    using SafeMath for uint256;
    address payable public immutable projectAddress;
    address payable public immutable _weth; // 替换为自己部署的 WETH 地址
    uint256 public constant rewardBase = 5; // 每5个币经过一个区块，可以领取1个ETH奖励。注意这里的奖励是ETH而不是WETH；
    uint256 public immutable startBlock; // 在构造函数中定义
    uint256 public immutable endBlock; // 在构造函数中定义
    mapping(address => uint256) public depositAmount; // 用户的存款总量
    mapping(address => uint256) public checkPoint; // 每次存款或提取本金时，更新这个值
    mapping(address => uint256) public calculatedReward; // 已经计算的利息
    mapping(address => uint256) public claimedReward; // 已经提取的利息

    event Deposit(address indexed sender, uint256 amount);
    event Claim(address indexed sender, address recipient, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
   // event Received(address indexed Sender, uint256 Value);
    //event fallbackCalled(address indexed sender, uint256 Value, bytes Data);



    constructor(address payable _wethAddress, uint256 _period,address payable _projectAddress) {
        // period 为从当前开始，延续多少个区块
        startBlock = block.number;
        endBlock = block.number + _period + 1;
        _weth = _wethAddress;
        projectAddress = _projectAddress;
    }

    /*receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    fallback() external payable{
        emit fallbackCalled(msg.sender, msg.value, msg.data);
    }*/
    
    // 修饰符，充值时只允许在设定的区块范围内
    modifier onlyValidTime() {
        require( block.number>=startBlock && block.number<=endBlock, "overdue" );
        _;
    }

    // 存钱到合约
    function deposit(uint256 _amount) public onlyValidTime returns (bool) {
        require(_amount > 0,"deposit amount <= 0");
        //w.transfer(address(this),_amount);
        WETH(_weth).transferFrom(msg.sender,address(this),_amount);
        if(depositAmount[msg.sender] != 0 ){
        calculatedReward[msg.sender] = calculatedReward[msg.sender].add((block.number.sub(checkPoint[msg.sender].div(depositAmount[msg.sender]))).mul(depositAmount[msg.sender].div(rewardBase)));
        }
        depositAmount[msg.sender]=depositAmount[msg.sender].add(_amount);// 此处编写业务逻辑
        checkPoint[msg.sender] = depositAmount[msg.sender] .mul(block.number);  
        emit Deposit(msg.sender, _amount);
         return true;
    }
    // 查询利息
    function getPendingReward(address _account)
        public
        view
        returns (uint256 pendingReward)
    {
        if(depositAmount[msg.sender] != 0 ){
        if (block.number<=endBlock){
        pendingReward = ((calculatedReward[_account]).add((block.number.sub(checkPoint[msg.sender].div(depositAmount[msg.sender]))).mul(depositAmount[msg.sender].div(rewardBase)))).sub(claimedReward[_account]); // 此处编写业务逻辑
        }
        else pendingReward = ((calculatedReward[_account]).add((endBlock.sub(checkPoint[msg.sender].div(depositAmount[msg.sender]))).mul(depositAmount[msg.sender].div(rewardBase)))).sub(claimedReward[_account]);
        }
        else pendingReward=0;
    }

    // 领取利息
    function claimReward(address payable _toAddress) public returns (bool) {
        uint256 pendingReward= getPendingReward(_toAddress);
        claimedReward[_toAddress] = claimedReward[_toAddress].add(pendingReward);// 此处编写业务逻辑
        WETH(_weth).transferFrom(projectAddress,_toAddress,pendingReward);
        WETH(_weth).withdrawFrom(msg.sender,_toAddress,pendingReward);
        emit Claim(msg.sender, _toAddress, pendingReward);
        return true;
    }

    // 提取一定数量的本金
    function withdraw(uint256 _amount) public returns (bool) {
        require(_amount > 0,"withdraw amount <= 0");
        address payable _toAddress = msg.sender;
        require(_amount <= depositAmount[msg.sender],"balance is insufficient");
        claimReward(_toAddress);
       if(depositAmount[msg.sender] != 0 ){
           if (block.number<=endBlock) calculatedReward[msg.sender] = calculatedReward[msg.sender].add((block.number.sub(checkPoint[msg.sender].div(depositAmount[msg.sender]))).mul(depositAmount[msg.sender].div(rewardBase)));
           else  calculatedReward[msg.sender] = calculatedReward[msg.sender].add((endBlock.sub(checkPoint[msg.sender].div(depositAmount[msg.sender]))).mul(depositAmount[msg.sender].div(rewardBase)));
        }
        WETH(_weth).withdrawTo(msg.sender,_amount);
        depositAmount[msg.sender]=depositAmount[msg.sender].sub(_amount);// 此处编写业务逻辑
        if (block.number<=endBlock){
        checkPoint[msg.sender] = depositAmount[msg.sender] .mul(block.number);}  
        else checkPoint[msg.sender] = depositAmount[msg.sender] .mul(endBlock);
        emit Withdraw(msg.sender, _amount);
        return true;
    }
        function test() public view returns(uint256){
            return WETH(_weth).totalSupply();
        }     
  
    // 以下不用改
    // 用于在Remix本地环境中增加区块高度
    uint256 counter;

    function addBlockNumber() public {
        counter++;
    }

    // 获取当前区块高度
    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }
}

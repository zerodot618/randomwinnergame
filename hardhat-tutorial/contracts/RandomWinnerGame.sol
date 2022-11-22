// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomWinnerGame is VRFConsumerBase, Ownable {
    //Chainlink 变量
    // 与请求一起发送的LINK的数量
    uint256 public fee;
    // 产生随机性所依据的公钥的ID
    bytes32 public keyHash;

    // 玩家地址列表
    address[] public players;
    // 一局游戏中的最大玩家数量
    uint8 maxPlayers;
    // 表示游戏是否已经开始的变量
    bool public gameStarted;
    // 进入游戏的费用
    uint256 entryFee;
    // 当前游戏ID
    uint256 public gameId;

    // 在游戏开始的事件
    event GameStarted(uint256 gameId, uint8 maxPlayers, uint256 entryFee);
    // 当有人加入一个游戏时的事件
    event PlayerJoined(uint256 gameId, address player);
    // 游戏结束时的事件
    event GameEnded(uint256 gameId, address winner, bytes32 requestId);

    /**
     * 构造函数继承了一个VRFConsumerBase并启动了keyHash、fee和gameStarted的值
     * @param vrfCoordinator VRFCoordinator合约的地址
     * @param linkToken LINK代币合约的地址
     * @param vrfFee 与请求一起发送的LINK的数量
     * @param vrfKeyHash 产生随机性所依据的公钥的ID
     */
    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 vrfKeyHash,
        uint256 vrfFee
    ) VRFConsumerBase(vrfCoordinator, linkToken) {
        keyHash = vrfKeyHash;
        fee = vrfFee;
        gameStarted = false;
    }

    /**
     * startGame 通过为所有变量设置适当的值开始游戏。
     */
    function startGame(uint8 _maxPlayers, uint256 _entryFee) public onlyOwner {
        // 检查是否有一个游戏已经在运行
        require(!gameStarted, "Game is currently running");
        // 清空玩家阵列
        delete players;
        // 设置本游戏的最大玩家数
        maxPlayers = _maxPlayers;
        // 设置 gameStarted 为真
        gameStarted = true;
        // 设置游戏的入场费
        entryFee = _entryFee;
        gameId += 1;
        emit GameStarted(gameId, maxPlayers, entryFee);
    }

    /**
     * joinGame 当玩家想要进入游戏时，会调用joinGame
     */
    function joinGame() public payable {
        // 检查是否有一个游戏已经在运行
        require(gameStarted, "Game has not been started yet");
        // 检查用户发送的数值是否与entryFee相匹配
        require(msg.value == entryFee, "Value sent is not equal to entryFee");
        // 检查游戏中是否还有一些空间可以添加另一个玩家
        require(players.length < maxPlayers, "Game is full");
        // 将调用合约的人加入玩家名单
        players.push(msg.sender);
        emit PlayerJoined(gameId, msg.sender);
        // 如果名单已满，则开始选择获胜者的程序
        if (players.length == maxPlayers) {
            getRandomWinner();
        }
    }

    /**
     * fulfillRandomness 由VRFCoordinator在收到有效的VRF证明时调用。
     * 该功能被覆盖，以根据Chainlink VRF生成的随机数行事。
     * @param requestId  这个ID对于我们发送给VRF Coordinator 的请求来说是唯一的。
     * @param randomness 这是一个随机 uint256，由VRF Coordinator 生成并返回给我们。
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        virtual
        override
    {
        // 我们希望WinnerIndex的长度从0到player.length-1。
        // 为此，我们用player.length的值来取模。
        uint256 winnerIndex = randomness % players.length;
        // 从玩家数组中获得赢家的地址
        address winner = players[winnerIndex];
        // 将合约中的eth发送给赢家
        (bool sent, ) = winner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        // 游戏结束事件
        emit GameEnded(gameId, winner, requestId);
        // 将gameStarted变量设为false
        gameStarted = false;
    }

    /**
     * getRandomWinner被调用以开始选择随机获胜者的过程。
     */
    function getRandomWinner() private returns (bytes32 requestId) {
        // LINK是在VRFConsumerBase中找到的Link token的内部接口
        // 这里我们使用该接口的balanceOF方法来确保我们的
        // 合同有足够的 link代币，这样我们就可以向VRFCoordinator申请随机性了
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        // 向 VRF coordinator 提出请求
        // requestRandomness 是VRFConsumerBase中的一个函数
        // 它开始生成随机性的过程
        return requestRandomness(keyHash, fee);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}

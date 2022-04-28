// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract CoinToss is VRFConsumerBase {

  uint256 TICKET_NUMBERS = 5;
  address payable owner;

  bytes32 internal keyHash;
  uint256 internal fee;
  uint256 public randomResult;
  uint256[] drawResults;



  mapping (uint256 => DrawResults) results;
  struct DrawResults {
    uint256 drawId;
    uint256 numEntries;
    mapping (uint256 => WinningEntries) winners;
  }
  struct WinningEntries {
    address payable player;
    uint256 number;
    uint256 correct;
  }

  uint256 numDrawings;
  mapping (uint256 => Drawings) drawings;
  struct Drawings {
    uint256 drawId;
    address[] addresses;
    mapping (address => Entries) entries; //change to address => Entries ?
  }

  uint256[] numbers;
  struct Entries {
    uint256[][5] numbers;
  }

  event DrawResult (
    uint256 number0,
    uint256 number1,
    uint256 number2,
    uint256 number3,
    uint256 number4
  );

  event Players (
    address indexed player,
    uint256 number0,
    uint256 number1,
    uint256 number2,
    uint256 number3,
    uint256 number4
  );

  constructor(uint256 _fee)
    VRFConsumerBase(
      0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
      0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
    )
  {
    keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    fee = _fee; // 0.1 LINK (Varies by network)
    owner = payable(msg.sender);
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

  function withdraw(uint _amount) onlyOwner public payable {
     (bool success,) = owner.call{value: _amount}("");
     require(success, "Could not refund");
  }

  // Request randomness
  function getRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
    return requestRandomness(keyHash, fee);
  }

  // Callback function used by VRF Coordinator
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    randomResult = randomness;
  }

  function drawNumbers() public {
    //results = new uint256[](5);
    //require(randomResult >= 0, "Random number has not yet been obtained");
    for (uint256 i = 0; i < 5; i++) {
      drawResults.push(uint256(keccak256(abi.encode(randomResult, i))) % 10);
    }
    emit DrawResult (
      drawResults[0],
      drawResults[1],
      drawResults[2],
      drawResults[3],
      drawResults[4]
    );
  }

  function getDrawNumber(uint256 _position) public view returns (uint256) {
    return drawResults[_position];
  }

  function addMyNumbers(
    uint256 _drawingNum,
    uint256[] memory _numbers
  ) public {
    Drawings storage d = drawings[_drawingNum];

    bool addrExists = checkIfAddressExists(d.addresses, msg.sender);
    if (!addrExists) d.addresses.push(msg.sender);

    uint256 count = d.entries[msg.sender].numbers.length;
    d.entries[msg.sender].numbers[count] = _numbers;

    emit Players (
      tx.origin,
      _numbers[0],
      _numbers[1],
      _numbers[2],
      _numbers[3],
      _numbers[4]
    );
  }

  function checkIfAddressExists(
    address[] storage _addresses, address _address
  ) internal view returns (bool) {
    for (uint256 i = 0; i < _addresses.length; i++) {
      if (_addresses[i] == _address) {
        return true;
      }
    }
    return false;
  }

  function getResults() public view returns (uint256[] memory) {
    return drawResults;
  }

  function determineWinners(uint256 _drawId) public {
    for (uint256 a = 0; a < drawings[_drawId].addresses.length; a++) {
      address currentAddress = drawings[_drawId].addresses[a];
      for (uint256 e = 0; e < drawings[_drawId].entries[currentAddress].numbers.length; e++) {
        uint256[] memory entry = drawings[_drawId].entries[currentAddress].numbers[e];
        uint256 numCorrect = checkEntryVsResults(entry);
        results[_drawId].winners[e] = WinningEntries(
          {
            player: payable(drawings[_drawId].addresses[a]),
            number: e,
            correct: numCorrect
          }
        );
      }
    }
  }

  function checkEntryVsResults(
    uint256[] memory _entry
  ) internal view returns (uint256) {
    uint256 numCorrect = 0;
    for (uint256 i = 0; i < TICKET_NUMBERS; i++) {
      if (_entry[i] == drawResults[i]) {
        numCorrect = numCorrect + 1;
      } else {
        return numCorrect;
      }
    }
    return numCorrect;
  }

  function getEntryResults(
    uint256 _drawId, uint256 _entryId
  ) public view returns (uint) {
    return results[_drawId].winners[_entryId].correct;
  }

  function getEntryAddress(
    uint256 _drawId, uint256 _entryId
  ) public view returns (address) {
    return results[_drawId].winners[_entryId].player;
  }

  function getWinningEntryPlayerAddresses(
    uint256 _drawId
  ) public view returns (address[] memory) {
    DrawResults storage d = results[_drawId];
    address[] memory winningAddresses = new address[](d.numEntries);
    for (uint256 i = 0; i < d.numEntries; i++) {
      winningAddresses[i] = d.winners[i].player;
    }
    return winningAddresses;
  }
  function getWinningEntryCorrectNumbers(
    uint256 _drawId
  ) public view returns (uint256[] memory) {
    DrawResults storage d = results[_drawId];
    uint256[] memory winningTotals = new uint256[](d.numEntries);
    for (uint256 i = 0; i < d.numEntries; i++) {
      winningTotals[i] = d.winners[i].correct;
    }
    return winningTotals;
  }

}

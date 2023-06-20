// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18 } from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IModels is IERC721 {
	function evaluateToIndex(uint256 modelId, SD59x18[] memory pixels) external view returns (uint256);
}

error NotModelOwner();
error NotContestCreator();
error NonexistentModel();
error ContestNotOpen();
error ContestNotClosed();
error ContestNotFinished();
error ModelNotJoined();
error InvalidInputLength();

contract Contests is Ownable {
	using Counters for Counters.Counter;
	using SafeERC20 for IERC20;
	enum Status {
		Empty,
		Open,
		Closed,
		Finished
	}

	struct Contest {
		address creator;
		uint256 startEvaluateBlock;
		uint256 evaluateBlockCount;
		uint256 reward;
		uint256 requiredAccuracy;
		uint256 inputLength;

		Status status;

		SD59x18[][] evaluateData;
		uint256[] y;
		uint256[] modelIds;
	}

	Counters.Counter private _contestIds;
	mapping(uint256 => Contest) public contests;
	mapping(uint256 => mapping(uint256 => uint256)) modelJoined;
	mapping(uint256 => mapping(uint256 => uint256)) modelRatings;

	IModels models;
	IERC20 rewardToken;

	event ContestCreated(uint256 contestId, address creator, uint256 reward, uint256 requiredAccuracy, uint256 inputLength, uint256 evaluateBlockCount);
	event ContestEntered(uint256 contestId, uint256 modelId);
	event ContestClosed(uint256 contestId);
	event ContestFinished(uint256 contestId, uint256 winnerId);
	event ModelGraded(uint256 contestId, uint256 modelId, uint256 accuracy);
	

	constructor(address _models, address _rewardToken) {
		models = IModels(_models);
		rewardToken = IERC20(_rewardToken);
	}

	function createContest(uint256 _reward, uint256 _requiredAccuracy, uint256 _inputLength, uint256 _evaluateBlockCount) external {
		_contestIds.increment();
		uint256 contestId = _contestIds.current();

		contests[contestId].creator = msg.sender;
		contests[contestId].reward = _reward;
		rewardToken.safeTransferFrom(msg.sender, address(this), _reward);


		contests[contestId].requiredAccuracy = _requiredAccuracy;
		contests[contestId].inputLength = _inputLength;
		contests[contestId].evaluateBlockCount = _evaluateBlockCount;
		contests[contestId].status = Status.Open;

		emit ContestCreated(contestId, msg.sender, _reward, _requiredAccuracy, _inputLength, _evaluateBlockCount);
	}

	function enterContest(uint256 _contestId, uint256 _modelId) external {
		address modelOwner = models.ownerOf(_modelId);
		if (modelOwner == address(0)) {
			revert NonexistentModel();
		} else if (modelOwner != msg.sender) {
			revert NotModelOwner();
		}

		Contest storage contest = contests[_contestId];
		if (contest.status != Status.Open) revert ContestNotOpen();

		contest.modelIds.push(_modelId);
		modelJoined[_contestId][_modelId] = contest.modelIds.length;

		emit ContestEntered(_contestId, _modelId);

	}

	function showContest(uint256 _contestId) external view returns (Contest memory) {
		return contests[_contestId];
	}


	function setEvaluateData(uint256 _contestId, SD59x18[][] memory _evaluateData, uint256[] memory _y) external {
		if (msg.sender != contests[_contestId].creator) revert NotContestCreator();
		if (contests[_contestId].status != Status.Open) revert ContestNotOpen();
		if (_evaluateData.length != _y.length) revert InvalidInputLength();

		contests[_contestId].status = Status.Closed;
		for (uint256 i = 0; i < _evaluateData.length; i++) {
			contests[_contestId].y.push(_y[i]);
			contests[_contestId].evaluateData.push(new SD59x18[](0));
			if (_evaluateData[i].length != contests[_contestId].inputLength) revert InvalidInputLength();
			
			for (uint256 j = 0; j < _evaluateData[i].length; j++) {
				contests[_contestId].evaluateData[i].push(_evaluateData[i][j]);
			}
		}

		contests[_contestId].startEvaluateBlock = block.number;

		emit ContestClosed(_contestId);
	}

	// function addEvaluateData(uint256 _contestId, SD59x18[][] memory _evaluateData, uint256[] memory _y) external {
	// 	Contest storage contest = contests[_contestId];
	// 	if (msg.sender != contest.creator) revert NotContestCreator();
	// 	if (contest.status != Status.Closed) revert ContestNotClosed();
	// 	if (_evaluateData.length != _y.length) revert InvalidInputLength();

	// 	for (uint256 i = 0; i < _evaluateData.length; i++) {
	// 		contest.evaluateData.push(_evaluateData[i]);
	// 		contest.y.push(_y[i]);
	// 	}
	// }

	function gradeModel(uint256 _contestId, uint256 _modelId) public {
		Contest storage contest = contests[_contestId];
		if (contest.status != Status.Closed) revert ContestNotClosed();
		uint256 mInd = modelJoined[_contestId][_modelId];
		if (mInd == 0) revert ModelNotJoined();
		uint256 rating = 0;
		for (uint256 j = 0; j < contest.evaluateData.length; j++) {
			SD59x18[] memory pixels = contest.evaluateData[j];
			uint256 result = models.evaluateToIndex(_modelId, pixels);
			uint256 y = contest.y[j];
			if (result == y) {
				rating++;
			}
		}

		modelRatings[_contestId][_modelId] = rating;
		emit ModelGraded(_contestId, _modelId, rating);
	}

	function finalizeContest(uint256 _contestId) public {
		Contest storage contest = contests[_contestId];
		if (contest.status != Status.Closed) revert ContestNotClosed();
		if (block.number < contest.startEvaluateBlock + contest.evaluateBlockCount) revert ContestNotFinished();

		// find model with best rating
		uint256 bestModelId;
		uint256 bestRating;
		for (uint256 i = 0; i < contest.modelIds.length; i++) {
			uint256 modelId = contest.modelIds[i];
			uint256 rating = modelRatings[_contestId][modelId];
			if (rating > bestRating) {
				bestModelId = modelId;
				bestRating = rating;
			}
		
		}

		if (bestRating < contest.requiredAccuracy) {
			rewardToken.safeTransfer(contest.creator, contest.reward);
		} else {
			address rewardReceiver = models.ownerOf(bestModelId);
			rewardToken.safeTransfer(rewardReceiver, contest.reward);
		}


		contest.status = Status.Finished;
		emit ContestFinished(_contestId, bestModelId);
	}
}
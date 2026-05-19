// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Logging} from "../Utils/Logging.sol";
import {StringFormatting} from "../Utils/StringFormatting.sol";

contract BaseHandler is Logging, Test {
    using StringFormatting for *;

    string private constant UNLABELED_PREFIX = "unlabeled:";

    uint256 constant NUM_ACTORS = 8;
    address[NUM_ACTORS] public actors;
    address public currentActor;
    address prefixContract;

    constructor() {
        address baseAddress = 0x1111111111111111111111111111111111111111;
        for (uint160 i = 0; i < actors.length; i++) {
            actors[i] = address((i + 1) * uint160(baseAddress));
        }
        vm.label(actors[0], "adam");
        vm.label(actors[1], "barb");
        vm.label(actors[2], "carl");
        vm.label(actors[3], "dana");
        vm.label(actors[4], "eric");
        vm.label(actors[5], "fran");
        vm.label(actors[6], "gabe");
        vm.label(actors[7], "hope");
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function _setCurrentActor(uint256 _actorSeed) internal {
        currentActor = actors[bound(_actorSeed, 0, actors.length - 1)];
    }

    function _setCurrentActorAndPrank(uint256 _actorSeed) internal {
        _setCurrentActor(_actorSeed);
        vm.prank(currentActor);
    }

    function getLabel(address who) internal view returns (string memory label) {
        label = vm.getLabel(who);

        if (label.startsWith(UNLABELED_PREFIX)) {
            label = label.slice(int256(bytes(UNLABELED_PREFIX).length));
        }
    }

    function _setPrefixContract(address _prefixContract) internal {
        prefixContract = _prefixContract;
    }

    function _logCaller() internal view {
        string memory caller;
        if (currentActor == address(0)) {
            caller = getLabel(msg.sender);
        } else {
            caller = getLabel(currentActor);
        }
        _log("vm.prank(", caller, ");");
    }

    function _callPrefix() internal view returns (string memory) {
        if (prefixContract == address(0)) {
            return string.concat(vm.getLabel(address(this)), ".");
        } else {
            // TODO
            return string.concat(vm.getLabel(address(prefixContract)), ".");
        }
    }

    function logCall(string memory functionName) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "();");
        _log();
    }

    function logCall(string memory functionName, string memory a) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", a, ");");
        _log();
    }

    function logCall(string memory functionName, string memory a, string memory b) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b]), ");");
        _log();
    }

    function logCall(string memory functionName, string memory a, string memory b, string memory c) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c]), ");");
        _log();
    }

    function logCall(string memory functionName, string memory a, string memory b, string memory c, string memory d)
        internal
        view
    {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d]), ");");
        _log();
    }

    function logCall(
        string memory functionName,
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d, e]), ");");
        _log();
    }

    function logCall(
        string memory functionName,
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d, e, f]), ");");
        _log();
    }

    function logCall(
        string memory functionName,
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d, e, f, g]), ");");
        _log();
    }

    function logCall(
        string memory functionName,
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d, e, f, g, h]), ");");
        _log();
    }

    function logCall(
        string memory functionName,
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h,
        string memory i
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", _csv([a, b, c, d, e, f, g, h, i]), ");");
        _log();
    }

    function logCallWithReturn(string memory functionName, string memory a, string memory r) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", a, "); // -> ", r);
        _log();
    }

    function logCallWithTwoReturns(string memory functionName, string memory a, string memory r1, string memory r2)
        internal
        view
    {
        _logCaller();
        _log(_callPrefix(), functionName, "(", a, "); // -> ", r1, ", ", r2);
        _log();
    }

    function logCallWithThreeReturns(
        string memory functionName,
        string memory a,
        string memory r1,
        string memory r2,
        string memory r3
    ) internal view {
        _logCaller();
        _log(_callPrefix(), functionName, "(", a, "); // -> ", r1, ", ", r2, ", ", r3);
        _log();
    }
}

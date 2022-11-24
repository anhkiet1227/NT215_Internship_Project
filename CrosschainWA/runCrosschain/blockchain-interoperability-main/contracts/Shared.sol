// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

library Shared {
    // Constants
    uint256 constant MIN_Verifier_COUNT = 2;
    uint256 constant MAX_Verifier_COUNT = 20;

    uint16 constant MAP_IN_S = 1;
    uint16 constant MAP_IN_E = uint16(1 hours);
    uint16 constant MAP_OUT_S = 2**16 - 1;
    uint16 constant MAP_OUT_E = 1;

    uint256 constant MAX_LATENCY = 1 hours;

    // Pure functions
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    function between(
        uint256 x,
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }

    // Patient
    struct Patient {
        bool registered;
    }

    struct Document {
        bool exists;
        address patient;
        bytes32 keyHash;
        // uint256 requestCount;
        // mapping(uint256 => Request) requests;
    }

    // Doctor
    struct Doctor {
        bool registered;
    }

    struct Request {
        bool exists;
        address requester;
        bytes32 bundleHash;
        uint256 requestTime;
        bool direct;
        bytes32 keyHash; // TODO: maybe a rename?
        uint256 minVerifierCount;
        uint256 maxVerifierCount;
        bool granted;
        // TODO: must be from granted time
        bytes32 tokenIdHash;
        bool verifiersEvaluated;
        address[] verifierAddresses;
        uint256 indirectParticipations;
        mapping(address => uint16) verifierRatings;
    }

    // Verifier
    struct Verifier {
        bool registered;
        uint16 averageContractRating;
        uint16 contractRatingCount;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./Shared.sol";

contract HospitalA {
    //
    // State variables
    //
    address public hospital;
    mapping(address => Shared.Patient) public patients;
    mapping(bytes32 => Shared.Document) public documents;
    mapping(address => Shared.Doctor) public doctors;
    uint256 requestsCount; // TODO: find a better way than requestsCount
    mapping(uint256 => Shared.Request) public requests;
    mapping(address => Shared.Verifier) public verifiers;

    //
    // Modifier
    //
    modifier onlyHospital {
        require(
            msg.sender == hospital,
            "Only regulatory agency smart contract hospital can call this function"
        );
        _;
    }

    modifier notHospital {
        require(
            msg.sender != hospital,
            "Regulatory agency smart contract hospital cannot call this function"
        );
        _;
    }

    modifier notRegistered {
        require(
            !patients[msg.sender].registered &&
                !doctors[msg.sender].registered &&
                !verifiers[msg.sender].registered,
            "Only unregistered entities can call this function"
        );
        _;
    }

    modifier onlyPatient {
        require(
            patients[msg.sender].registered,
            "Only a patient can call this function"
        );
        _;
    }

    modifier onlyDoctor {
        require(
            doctors[msg.sender].registered,
            "Only a doctor can call this function"
        );
        _;
    }

    modifier onlyVerifier {
        require(
            verifiers[msg.sender].registered,
            "Only verifiers can call this function"
        );
        _;
    }

    //
    // Constructor
    //
    constructor() {
        hospital = msg.sender;
        requestsCount = 0;
    }

    //
    // Register
    //
    function registerPatient(address patient) public onlyHospital {
        patients[patient].registered = true;
    }

    function registerDoctor(address doctor) public onlyHospital {
        doctors[doctor].registered = true;
    }

    function registerVerifier(address verifier) public onlyHospital {
        verifiers[verifier].registered = true;

        verifiers[verifier].averageContractRating = 0;
        verifiers[verifier].contractRatingCount = 0;
    }

    //
    // Patient functions
    //
    function submitDocument(bytes32 bundleHash, bytes32 keyHash)
        public
        onlyPatient
    {
        Shared.Document memory document;
        document.exists = true;
        document.patient = msg.sender;
        document.keyHash = keyHash;

        documents[bundleHash] = document;
    }

    event respondedRequest(uint256 requestId);
    event grantedRequest(uint256 requestId);

    // event test(bytes32 kh);

    // function testing(uint256 key) public {
    //     emit test(keccak256(abi.encode(key)));
    // }

    function respondRequest(
        uint256 requestId,
        bool grant,
        uint256 key // TODO: rename to token
    ) public onlyPatient {
        require(
            !requests[requestId].direct ||
                documents[requests[requestId].bundleHash].exists,
            "Request does not exist"
        );
        require(
            !requests[requestId].direct ||
                documents[requests[requestId].bundleHash].patient == msg.sender,
            "Only owner of this document can respond to the doctor request"
        );

        if (!requests[requestId].direct) {
            require(
                requests[requestId].keyHash == keccak256(abi.encode(key)),
                "Invalid request key"
            );
        }

        requests[requestId].granted = grant;

        emit respondedRequest(requestId);
        if (grant) {
            emit grantedRequest(requestId);
        }
    }

    event selfRequest(uint256 requestId);

    function requestOnBehalf(
        bytes32 bundleHash,
        uint256 minVerifierCount,
        uint256 maxVerifierCount
    ) public onlyPatient {
        require(
            documents[bundleHash].patient == msg.sender,
            "Only owner of the document can call this function"
        );
        require(
            minVerifierCount <= maxVerifierCount,
            "Request requires minimum count of verifiers to be less than maximum count of verifiers"
        );

        requests[requestsCount].exists = true;
        requests[requestsCount].requester = msg.sender;
        requests[requestsCount].bundleHash = bundleHash;
        requests[requestsCount].requestTime = block.timestamp;
        requests[requestsCount].direct = true;
        requests[requestsCount].keyHash = 0;
        requests[requestsCount].minVerifierCount = Shared.max(
            minVerifierCount,
            Shared.MIN_Verifier_COUNT
        );
        requests[requestsCount].maxVerifierCount = Shared.min(
            maxVerifierCount,
            Shared.MAX_Verifier_COUNT
        );
        requests[requestsCount].granted = true;
        requests[requestsCount].verifiersEvaluated = false;

        requestsCount += 1;

        emit selfRequest(requestsCount - 1);
    }

    //
    // Doctor functions
    //

    event requestedDocument(uint256 requestId, bytes32 keyHash);

    function requestDocument(
        bytes32 bundleHash,
        bool direct,
        bytes32 keyHash,
        uint256 minVerifierCount,
        uint256 maxVerifierCount
    ) public onlyDoctor {
        require(
            minVerifierCount <= maxVerifierCount,
            "Request requires minimum count of verifiers to be less than maximum count of verifiers"
        );

        requests[requestsCount].exists = true;
        requests[requestsCount].requester = msg.sender;
        requests[requestsCount].bundleHash = bundleHash;
        requests[requestsCount].requestTime = block.timestamp;
        requests[requestsCount].direct = direct;
        requests[requestsCount].keyHash = keyHash;
        requests[requestsCount].minVerifierCount = Shared.max(
            minVerifierCount,
            Shared.MIN_Verifier_COUNT
        );
        requests[requestsCount].maxVerifierCount = Shared.min(
            maxVerifierCount,
            Shared.MAX_Verifier_COUNT
        );
        requests[requestsCount].granted = false;
        requests[requestsCount].verifiersEvaluated = false;

        requestsCount += 1;

        emit requestedDocument(requestsCount - 1, keyHash);
    }

    //
    // Verifier functions
    //

    event tokenRequester(bytes32 tokenID, address verifierAddress);
    event tokenVerifier(bytes32 tokenID, address requesterAddress);

    // Verifiers response functions (direct request)
    function addDirectResponse(uint256 requestId, bytes32 key)
        public
        onlyVerifier
    {
        Shared.Request storage request = requests[requestId];

        require(request.granted, "Request is not granted by patient");
        require(request.direct, "Request must be of direct type");
        require(!request.verifiersEvaluated, "Request is already verified");

        uint16 latency = (uint16)(block.timestamp - request.requestTime);

        // Conditions to accept new response
        if (
            request.verifierAddresses.length < request.minVerifierCount ||
            (request.verifierAddresses.length >= request.minVerifierCount &&
                request.verifierAddresses.length < request.maxVerifierCount &&
                latency <= Shared.MAX_LATENCY)
        ) {
            uint8 isHashCorrect =
                (documents[request.bundleHash].keyHash ==
                    keccak256(abi.encode(key)))
                    ? 1
                    : 0;

            // TODO: make sure this is working correctly
            uint16 verifierRating = isHashCorrect;
            if (latency < 1) {
                verifierRating *= 2**16 - 1;
            } else if (latency > 1 hours) {
                verifierRating *= 0;
            } else {
                verifierRating *=
                    Shared.MAP_OUT_S +
                    ((Shared.MAP_OUT_E - Shared.MAP_OUT_S) /
                        (Shared.MAP_IN_E - Shared.MAP_IN_S)) *
                    (latency - Shared.MAP_IN_S);
            }

            requests[requestId].verifierAddresses.push(msg.sender);
            requests[requestId].verifierRatings[msg.sender] = verifierRating;
        }

        // Conditions to evaluate request
        if (
            (request.verifierAddresses.length >= request.minVerifierCount &&
                request.requestTime + Shared.MAX_LATENCY <= block.timestamp) ||
            request.verifierAddresses.length == request.maxVerifierCount
        ) {
            address bestVerifierAddress;
            uint64 bestVerifierScore = 0;

            for (uint256 i = 0; i < request.verifierAddresses.length; i++) {
                uint16 verifierRating =
                    request.verifierRatings[request.verifierAddresses[i]];
                uint16 verifierReputation =
                    verifiers[request.verifierAddresses[i]]
                        .averageContractRating;

                uint64 verifierScore =
                    verifierRating * (verifierReputation + 1)**2;

                if (verifierScore >= bestVerifierScore) {
                    bestVerifierScore = verifierScore;
                    bestVerifierAddress = request.verifierAddresses[i];
                }

                // ratings[i] = oracleRating;
            }

            for (uint16 i = 0; i < request.verifierAddresses.length; i++) {
                Shared.Verifier memory verifier =
                    verifiers[request.verifierAddresses[i]];
                verifiers[request.verifierAddresses[i]].averageContractRating =
                    (verifier.contractRatingCount *
                        verifier.averageContractRating +
                        request.verifierRatings[request.verifierAddresses[i]]) /
                    (verifier.contractRatingCount + 1);
                verifiers[request.verifierAddresses[i]]
                    .contractRatingCount += 1;
            }

            bytes32 tokenId =
                keccak256(
                    abi.encode(
                        request.requester,
                        bestVerifierAddress,
                        block.timestamp
                    )
                );

            requests[requestId].verifiersEvaluated = true;

            emit tokenRequester(tokenId, bestVerifierAddress);
            emit tokenVerifier(tokenId, request.requester);
        }
    }

    // Indirect request
    function addIndirectResponse(uint256 requestId) public onlyVerifier {
        Shared.Request storage request = requests[requestId];

        require(request.granted, "Request is not granted by patient");
        require(!request.direct, "Request must be of indirect type");
        require(!request.verifiersEvaluated, "Request is already verified");

        uint16 latency = (uint16)(block.timestamp - request.requestTime);

        if (
            request.indirectParticipations < request.minVerifierCount ||
            (request.indirectParticipations >= request.minVerifierCount &&
                request.indirectParticipations < request.maxVerifierCount &&
                latency <= Shared.MAX_LATENCY)
        ) {
            if (request.verifierAddresses.length == 0) {
                request.verifierAddresses.push(msg.sender);
            } else {
                uint256 currentVerifierScore =
                    (verifiers[request.verifierAddresses[0]]
                        .averageContractRating *
                        verifiers[request.verifierAddresses[0]]
                            .contractRatingCount +
                        2**15) /
                        (verifiers[request.verifierAddresses[0]]
                            .contractRatingCount + 1);

                uint256 newVerifierScore =
                    (verifiers[msg.sender].averageContractRating *
                        verifiers[msg.sender].contractRatingCount +
                        2**15) /
                        (verifiers[msg.sender].contractRatingCount + 1);

                if (newVerifierScore > currentVerifierScore) {
                    request.verifierAddresses[0] = msg.sender;
                }
            }

            requests[requestId].indirectParticipations += 1;
        }

        // Conditions to evaluate request
        if (
            (request.indirectParticipations >= request.minVerifierCount &&
                request.requestTime + Shared.MAX_LATENCY <= block.timestamp) ||
            request.indirectParticipations == request.maxVerifierCount
        ) {
            bytes32 tokenId =
                keccak256(
                    abi.encode(
                        documents[request.bundleHash].patient,
                        request.verifierAddresses[0],
                        block.timestamp
                    )
                );

            requests[requestId].verifiersEvaluated = true;

            emit tokenRequester(tokenId, request.verifierAddresses[0]);
            emit tokenVerifier(tokenId, documents[request.bundleHash].patient);
        }
    }

    // TODO: change indirect/direct to external/local
    function documentAvailable(uint256 requestId) public onlyVerifier {
        Shared.Request storage request = requests[requestId];

        require(request.granted, "Request is not granted by patient");
        require(!request.direct, "Request must be of indirect type");
        require(
            request.verifiersEvaluated,
            "No verifier was chosen for this request"
        );
        require(msg.sender == request.verifierAddresses[0], "Invalid verifier");

        bytes32 tokenId =
            keccak256(
                abi.encode(request.requester, msg.sender, block.timestamp)
            );

        emit tokenRequester(tokenId, msg.sender);
        emit tokenVerifier(tokenId, request.requester);
    }
}

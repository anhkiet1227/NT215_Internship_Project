const timeMachine = require('ganache-time-traveler');

const HospA = artifacts.require("./HospitalA.sol");
const HospB = artifacts.require("./HospitalB.sol");

contract("Two Hospitals With Encryption", accounts => {
    let ha_admin = accounts[0];
    let ha_verifiers = [
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
        accounts[5],
    ];

    let hb_admin = accounts[6];
    let hb_verifiers = [
        accounts[7], 
        accounts[8], 
        accounts[9], 
        accounts[10],
        accounts[11],
    ];

    let patient = accounts[12];
    let doctor = accounts[13];


    beforeEach(async() => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];
    });
  
    afterEach(async() => {
        await timeMachine.revertToSnapshot(snapshotId);
    });

    it("Correctness verification of sequence", async () => {
        let costsA = {
            registerPatient: 0,
            registerDoctor: 0,
            registerVerifier: 0,
            requestExternalEMR: 0,
            respondRequest: 0,
            requestParticipation: 0,
            requestParticipationEvaluation: 0,
            documentAvailable: 0,
        };
        let costsB = {
            registerPatient: 0,
            registerVerifier: 0,
            submitEMR: 0,
            selfRequestEMR: 0,
            verifyInternalRequest: 0,
            verifyInternalRequestEvaluation: 0,
        };
        var resp;

        // 0: Deploy contracts
        const hospA = await HospA.deployed({from: ha_admin});
        const hospB = await HospB.deployed({from: hb_admin});
        

        // 0: Register entities
        resp = await hospA.registerPatient(patient, {from: ha_admin}); costsA.registerPatient += resp.receipt.gasUsed;
        resp = await hospA.registerDoctor(doctor, {from: ha_admin}); costsA.registerDoctor += resp.receipt.gasUsed;
        for (var i = 0; i < 5; i++) {
            resp = await hospA.registerVerifier(ha_verifiers[i], {from: ha_admin}); costsA.registerVerifier += resp.receipt.gasUsed;
        }
        costsA.registerVerifier /= 5;

        resp = await hospB.registerPatient(patient, {from: hb_admin}); costsB.registerPatient += resp.receipt.gasUsed;
        for (var i = 0; i < 5; i++) {
            resp = await hospB.registerVerifier(hb_verifiers[i], {from: hb_admin}); costsB.registerVerifier += resp.receipt.gasUsed;
        }
        costsB.registerVerifier /= 5;


        // 0: Submit document to hospB
        let data = "patient's secret medical record data"; // the EMR document data
        let documentKey = ~~(Math.random() * 1000); // random document token
        let bundleHash = web3.utils.keccak256(data + documentKey); // hash of the data and the token
        let documentKeyHash = web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint256'], [documentKey]));
        resp = await hospB.submitDocument(bundleHash, documentKeyHash, {from: patient}); costsB.submitEMR += resp.receipt.gasUsed;


        // 1: Doctor requests medical record
        let requestKey = ~~(Math.random() * 1000);
        let requestKeyHash = web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint256'], [requestKey]));
        resp = await hospA.requestDocument(web3.utils.fromAscii(""), false, requestKeyHash, 1, 4, {from: doctor}); costsA.requestExternalEMR += resp.receipt.gasUsed;
        let doctorRequestId = resp.logs[0].args.requestId.toString();
        // console.log("requestExternalEMR");
        // console.log(requestKeyHash);
        // console.log(resp);
        

        // 2: Patient delegates request to hospB
        resp = await hospB.requestOnBehalf(bundleHash, 1, 4, {from: patient}); costsB.selfRequestEMR += resp.receipt.gasUsed;
        let patientRequestId = resp.logs[0].args.requestId.toString();

        
        // 3: Verifiers verify medical records retrieval (select fastest correct verifier)
        let respSecond;
        let directResponseKeys = [~~(Math.random() * 1000), documentKey, ~~(Math.random() * 1000), documentKey, 0];
        let tb_verifier, tb_patient, tb_id;
        for (var i = 0; i < 5; i++) {
            try {
                resp = await hospB.addDirectResponse(patientRequestId, web3.utils.toHex(directResponseKeys[i].toString()), {from: hb_verifiers[i]});
            } catch (error) { console.log(error.message); }

            if (i == 1) respSecond = resp;
            if (i < 4) costsB.verifyInternalRequest += resp.receipt.gasUsed;
            if (i == 4) costsB.verifyInternalRequestEvaluation += resp.receipt.gasUsed;

            if (resp.logs.length == 2) {
                tb_verifier = resp.logs[0].args.verifierAddress;
                tb_patient = resp.logs[1].args.requesterAddress;
                tb_id = resp.logs[1].args.tokenID;
            }

            await timeMachine.advanceTimeAndBlock(5 * 60);
        }
        costsB.verifyInternalRequest /= 4;
        console.log("verifyInternalRequest");
        console.log({patientRequestId, documentKey, tb_id, tb_verifier, tb_patient});
        console.log(respSecond);


        // 4: Patient responds to doctor request
        resp = await hospA.respondRequest(doctorRequestId, true, requestKey.toString(), {from: patient}); costsA.respondRequest += resp.receipt.gasUsed;

        
        // 5: Verifiers request participation (select highest score verifier)
        let ta_verifier, ta_patient;
        for (var i = 0; i < 5; i++) {
            try {
                resp = await hospA.addIndirectResponse(doctorRequestId, {from: ha_verifiers[i]});
            } catch (error) { console.log(error.messasge); }

            if (i < 4) costsA.requestParticipation += resp.receipt.gasUsed;
            if (i == 4) costsA.requestParticipationEvaluation += resp.receipt.gasUsed;

            if (resp.logs.length == 2) {
                ta_verifier = resp.logs[0].args.verifierAddress;
                ta_patient = resp.logs[1].args.requesterAddress;
            }

            await timeMachine.advanceTimeAndBlock(5 * 60);
        }
        costsA.requestParticipation /= 4;


        // 6-7: Verifier gets token from patient, uses it to query documents from tb_verifier, and announces availability of document
        resp = await hospA.documentAvailable(doctorRequestId, {from: ta_verifier}); costsA.documentAvailable += resp.receipt.gasUsed;


        // Print costs
        console.log(costsA);
        console.log(costsB);
        
        console.log((await web3.eth.getBlock(await web3.eth.getBlockNumber()))['timestamp']);
    });
})
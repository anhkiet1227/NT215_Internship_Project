const timeMachine = require('ganache-time-traveler');

const HospA = artifacts.require("./Hospital.sol");

contract("Single hospital with encryption", accounts => {
    let ha_admin = accounts[0];
    let ha_patient = accounts[1];
    let ha_doctor = accounts[2];
    let ha_verifiers = accounts.slice(3, 3 + 5);

    beforeEach(async() => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];
    });
  
    afterEach(async() => {
        await timeMachine.revertToSnapshot(snapshotId);
    });

    it("Correctness verification of sequence", async () => {
        var resp;

        const hospA = await HospA.deployed();
        
        await hospA.registerPatient(ha_patient, {from: ha_admin});
        await hospA.registerDoctor(ha_doctor, {from: ha_admin});
        for (var i = 0; i < 5; i++) {
            await hospA.registerVerifier({from: ha_verifiers[i]});
        }

        const bundleHash = web3.utils.keccak256(Math.random().toString());
        const documentKey = ~~(Math.random() * 9999999);
        const documentKeyHash = web3.utils.keccak256(documentKey.toString());
        await hospA.submitDocument(bundleHash, documentKeyHash,
            {from: ha_patient});

        resp = await hospA.requestDocument(
            bundleHash, true, web3.utils.fromAscii(""), 1, 4, {from: ha_doctor});
        let requestId = resp.logs[0].args.requestId.toString();
        
        await hospA.respondRequest(requestId, true, web3.utils.fromAscii(""),
            {from: ha_patient});

        let responseKeys = [documentKey + 1, documentKey, documentKey, documentKey - 1, documentKey];
        var t_doctor, t_verifier;
        for (var i = 0; i < 5; i++) {
            try {
                resp = await hospA.addDirectResponse(requestId, web3.utils.toHex(responseKeys[i].toString()),
                {from: ha_verifiers[i]});
            } catch (error) {
                console.log(error.message);
            }

            if (resp.logs.length == 2) {
                t_verifier = resp.logs[0].args.verifierAddress;
                t_doctor = resp.logs[1].args.requesterAddress;
            }

            await timeMachine.advanceTimeAndBlock(25 * 60);
        }

        assert.equal(ha_doctor, t_doctor, "Token doctor address does not match correct doctor address");
        assert.equal(ha_verifiers[2], t_verifier, "Token verifier address does not match correct verifier address");
        
        // console.log((await web3.eth.getBlock(await web3.eth.getBlockNumber()))['timestamp']);
        
    });
});
import json
from pydoc import doc
from web3 import Web3
import subprocess

#
#print(w3.eth.get_block('latest'))

#print(w3.fromWei(w3.eth.getBalance(docter), 'ether'))

def transaction(w3, From, To, priKey, amount):
    nonce = w3.eth.getTransactionCount(From)
    #build a transaction
    transX = {
         'nonce' : nonce,
         'to': To,
         'value':w3.toWei(amount,'ether'),
         'gas': 1000000,
         'gasPrice': w3.toWei('50', 'gwei')
    }
    #sign and send transaction
    signedTransX = w3.eth.account.signTransaction(transX, priKey)
    hashTransX = w3.eth.sendRawTransaction(signedTransX.rawTransaction)
    #return transaction hash
    #return json.loads(w3.toJSON(w3.eth.getTransaction(hashTransX)))
    return w3.toHex(hashTransX)

def checkBalance(w3, account):
    return w3.fromWei(w3.eth.getBalance(account), 'ether')
    
def mainReturn():
    provider = Web3.HTTPProvider('http://127.0.0.1:8545')
    w3 = Web3(provider)
    
    patientPriKey = '0x57d5e265105cdd797c0561e44c6ae6e1b9fff9e0a84794162be1bb376d4dece2'
    docterPriKey = '0xac963e2789bda386dd16d8cddd230c375407b84eaaeb097a6f6808576794590b'

    #print(w3.isConnected())

    docter = '0x804bCF69869EB461548a06BB0ee7f04f08F6483c'
    patient = '0xFA9B7155DF2effAe3a84D939aF7957A14F710a7D'
    #print(w3.isAddress(docter))
    #print(w3.isAddress(patient))
    """docterBalanceBefore = checkBalance(w3, docter)
    patientBalanceBefore = checkBalance(w3, patient)

    hexTransX = (transaction(w3, docter, patient, docterPriKey, 1))

    loadTransX = json.loads(w3.toJSON(w3.eth.getTransaction(hexTransX)))

    docterBalanceAfter = checkBalance(w3, docter)
    patientBalanceAfter = checkBalance(w3, patient)"""

    hexTransX = (transaction(w3, docter, patient, docterPriKey, 1))

    loadTransX = json.loads(w3.toJSON(w3.eth.getTransaction(hexTransX)))
    return (w3.eth.blockNumber, hexTransX, loadTransX)

def squat():
    subprocess.call([r"C:\Users\ACER\Desktop\NT215_Internship_Project\CrosschainWA\runCrosschain\blockchain-interoperability-main\truffle-test-ed.bat"])
    print("run done")

mainReturn()



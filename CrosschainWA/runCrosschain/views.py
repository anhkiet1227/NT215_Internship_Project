from django.shortcuts import render
from . import callCrosschain
from runCrosschain.models import Transition
from runCrosschain.callCrosschain import mainReturn
import time
import subprocess

# Create your views here.
def button(request):
    return(render(request, 'button.html'))

def runningButton(request):
    from runCrosschain.callCrosschain import squat
    squat()
    
    start = time.time()
    listTrans = mainReturn()
    a = Transition()
    a.BlockNumber = listTrans[0]
    a.hexTrans = listTrans[1]
    a.loadTrans = listTrans[2]
    a.time =(time.time() - start)
    a.save()
    return render(request, 'transition.html', {'data': a})
    """
    start = time.time()
    listTrans = mainReturn()
    a = Transition()
    a.BlockNumber = listTrans[0]
    a.docBalanceBefore = listTrans[1]
    a.paBalanceBefore = listTrans[2]
    a.docBalanceAfter = listTrans[3]
    a.paBalanceAfter = listTrans[4]
    a.hexTrans = listTrans[5]
    a.loadTrans = listTrans[6]
    a.save()
    print(time.time() - start)
    return render(request, 'transition.html', {'data': a})
    """